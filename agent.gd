extends Node2D

@onready var ship = get_parent()
@onready var debug_path = ship.get_node('../debug_path')

var ticks = 0
var spin = 0
var thrust = false
var selected_gem = null
#TODO at the beggining precompute shortest path that takes all the gems (dijkstra/astar)
#TODO smoothen path if you see next point remove the point between
#TODO thrust only when dist is bigger than velocity

func action(_walls: Array[PackedVector2Array], _gems: Array[Vector2], 
			_polygons: Array[PackedVector2Array], _neighbors: Array[Array]):
	debug_path.default_color = Color.MAROON
	
	var mouse_pos = get_viewport().get_mouse_position()
	var mouse_polygon = find_polygon_with_point(mouse_pos,_polygons)
	
	
	if selected_gem == null:
		selected_gem = find_closest_gem(_gems)
	else:
		var possible_gem = find_closest_gem(_gems)
		var dist_sg = ship.position.distance_to(selected_gem)
		var dist_pg = ship.position.distance_to(possible_gem)
		if (dist_pg < dist_sg + 100) and dist_pg < 200:
			selected_gem = possible_gem
	var ship_actual_polygon = find_polygon_with_point(ship.position,_polygons)
	var gem_polygon = find_polygon_with_point(selected_gem, _polygons)
	if ship_actual_polygon.value == null or gem_polygon.value == null:
		return [1, 1, false]
	
	var polygon_path = find_polygon_path(ship_actual_polygon, gem_polygon, _polygons, _neighbors)
	var points_path = find_closest_path(polygon_path, _polygons, ship.position, selected_gem)
	var smoothened_path = smoothen_path(points_path,_walls)
	debug_path.points = smoothened_path
	var next_point = smoothened_path[1]
	var dist_to_target = ship.position.distance_to(next_point)
	#TODO for each point closer than 50 take next point
	if dist_to_target < 50 and smoothened_path.size() > 2:
		next_point = smoothened_path[2]
	spin = calculate_ship_spin2(ship,next_point)
	
	
	#DEBUG
	var speed_dist = (ship.position + ship.velocity).distance_to(ship.position)
	var dir_to_next_point = (ship.position + ship.velocity).angle_to_point(next_point)
	var rotation = wrapf(ship.rotation, -PI, PI)  # Normalize the rotation
	dir_to_next_point = wrapf(dir_to_next_point, -PI, PI)  # Normalize the target angle
	var angle_diff = wrapf(dir_to_next_point - rotation, -PI, PI)
	
	#SEED #1 - 595pts
	if dist_to_target > 50 or (speed_dist > 1 and abs(angle_diff) < 0.05):
		thrust = 1
	else:
		thrust = 0
	
	#!DEBUG
	#return [0, 0, false]
	return [spin, thrust, false]

func smoothen_path(points_path, _walls):
	var smoothened_path = [points_path[0]]
	var current_point = points_path[0]
	var last_non_intersecting_point = points_path[1]
	
	for i in range(2, points_path.size()):
		var p = points_path[i]
		var intersecting = false
		for w in _walls:
			if do_segments_intersect(current_point,p,w[0], w[1]):
				intersecting = true
		if intersecting == false:
			last_non_intersecting_point = p
		else:
			current_point = last_non_intersecting_point
			smoothened_path.push_back(last_non_intersecting_point)
	smoothened_path.push_back(points_path[points_path.size()-1])
	return smoothened_path


func do_segments_intersect(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	# Směrové vektory úseček
	var r = p2 - p1
	var s = q2 - q1
	
	# Určení determinantu
	var det = r.cross(s)
	# Pokud je determinant 0, úsečky jsou rovnoběžné nebo kolineární
	if det == 0:
		return false

	# Parametry t a u podle parametrických rovnic
	var t = (q1 - p1).cross(s) / det
	var u = (q1 - p1).cross(r) / det

	# Pokud jsou t a u v rozsahu [0, 1], úsečky se protínají
	return t >= 0 and t <= 1 and u >= 0 and u <= 1

func calculate_ship_spin2(x: Node2D, y: Vector2) -> int:
	var dist = x.position.distance_to(y)
	var dir_to_next_point = (x.position + x.velocity).angle_to_point(y)
	#if dist < 100:
	#	dir_to_next_point = x.position.angle_to_point(y)
	var rotation = wrapf(x.rotation, -PI, PI)  # Normalize the rotation
	dir_to_next_point = wrapf(dir_to_next_point, -PI, PI)  # Normalize the target angle
	
	# Calculate the angular difference
	var angle_diff = wrapf(dir_to_next_point - rotation, -PI, PI)
	
	if abs(angle_diff) > 0.05:  # If the difference is greater than the threshold
		return -1 if angle_diff < 0 else 1
	return 0

func find_closest_path(polygon_path, _polygons, start, end):
	var points_path = [start]
	if polygon_path.size() == 0:
		points_path.push_back(end)
		return points_path
	
	var current_poly_index = polygon_path[0]
	var current_poly = _polygons[current_poly_index]
	for i in range(1,polygon_path.size()):
		var next_poly_index = polygon_path[i]
		var next_poly = _polygons[next_poly_index]
		
		var intersect_point = find_intersection_mid_point(current_poly,next_poly)
		points_path.push_back(intersect_point)
		current_poly = next_poly
		#current_polygon = poly_index
		
	#points_path.push_back(next_point)
	points_path.push_back(end)
	return points_path

func find_intersection_mid_point(current_poly,next_poly):
	var intersecting_points = []
	for cp in current_poly:
		for np in next_poly:
			if cp == np and cp not in intersecting_points:
				intersecting_points.push_back(cp)
	
	if intersecting_points.size() != 2:
		print("ERROR SIZE")
	var new_x = (intersecting_points[0].x + intersecting_points[1].x) / 2
	var new_y = (intersecting_points[0].y + intersecting_points[1].y) / 2
	return Vector2(new_x,new_y)
	

func find_polygon_path(start_poly, end_poly, _polygons, _neighbors):
	var queue = [start_poly] #push_back, pop_front, pop_back
	#queue.push_back(start)
	var visited = []
	var path_map = {}

	while (!queue.is_empty()):
		var current_poly = queue.pop_front()
		if (current_poly.index == end_poly.index):
			return construct_path(path_map,start_poly.index,end_poly.index);
		
		for n in _neighbors[current_poly.index]:
			if n not in visited:
				queue.push_back({"index": n, "value": _polygons[n]})
				visited.append(n)
				path_map[n] = current_poly.index
	
	return end_poly.index

func construct_path(path_map, start_index, end_index):
	var path = []
	var current_index = end_index
	while current_index != start_index:
		path.insert(0,current_index)
		current_index = path_map.get(current_index)
	path.insert(0,start_index)
	return path

func find_polygon_with_point(point: Vector2, _polygons: Array[PackedVector2Array]):
	var result_polygon = null
	var polygon_index = 0
	for polygon in _polygons:
		if Geometry2D.is_point_in_polygon(point,polygon):
			result_polygon = polygon.duplicate()
			result_polygon.append(polygon[0])
			break
		polygon_index += 1
	return {"index": polygon_index, "value": result_polygon}

func find_closest_gem(_gems):
	var closest_gem_dist = 10000
	var result_gem = null
	for g in _gems:
		var dist = ship.position.distance_to(g)
		if dist < closest_gem_dist:
			closest_gem_dist = dist
			result_gem = g
			
	return result_gem

# Called every time the agent has bounced off a wall.
func bounce():
	return

# Called every time a gem has been collected.
func gem_collected():
	selected_gem = null
	return

# Called every time a new level has been reached.
func new_level():
	return
