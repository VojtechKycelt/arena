extends Node2D

@onready var ship = get_parent()
@onready var debug_path = ship.get_node('../debug_path')

var ticks = 0
var spin = 0
var thrust = false
var selected_gem = null
var _delta = 0
#TODO at the beggining precompute shortest path that takes all the gems (dijkstra/astar)
#TODO check path dist not euclidean dist if chosing closest gem
#TODO do not check gem distance from our position but position + velocity

#command line: /Users/sirwok/Downloads/Godot.app/Contents/MacOS/Godot
#/Users/sirwok/Downloads/Godot.app/Contents/MacOS/Godot --fixed-fps 1 -- -seed 1:5

func _process(delta: float) -> void:
	_delta = delta

func action(_walls: Array[PackedVector2Array], _gems: Array[Vector2], 
			_polygons: Array[PackedVector2Array], _neighbors: Array[Array]):
	debug_path.default_color = Color.MAROON
	debug_path.width = 10
	
	#TARGET CHOICE
	var ship_actual_polygon = find_polygon_with_point(ship.position,_polygons)
	if ship_actual_polygon.value == null:
		return [1, 1, false]

	if selected_gem == null:
		selected_gem = find_closest_gem(ship_actual_polygon,_gems,_polygons,_neighbors)
	
	#CHECK IF THERE ARE NO GEMS OR SHIP OUTSIDE NAVMESH AREA
	var mouse_pos = get_viewport().get_mouse_position()
	var mouse_polygon = find_polygon_with_point(mouse_pos,_polygons)
	var gem_polygon = find_polygon_with_point(selected_gem, _polygons)
	if ship_actual_polygon.value == null or gem_polygon.value == null:
		return [1, 1, false]
	
	#FIND PATH
	var polygon_path = find_polygon_path(ship_actual_polygon, gem_polygon, _polygons, _neighbors)
	var andrew_path = find_shady_andrew_closest_path(polygon_path,_polygons,ship.position,selected_gem)
	var smoothened_path = smoothen_path(andrew_path,_walls)
	var next_point = smoothened_path[1]
	
	#IF CLOSE TO NEXT POINT GO TO ANOTHER
	if smoothened_path.size() > 2:
		var p1 = smoothened_path[1]
		var p2 = smoothened_path[2]
		var d1 = ship.position.distance_to(p1)
		if d1 < 50:
			next_point = p2
	
	#CALCULATE SPIN AND THRUST
	thrust = calculate_ship_thrust(next_point)
	spin = calculate_ship_spin(ship,next_point, thrust)
	
	debug_path.points = smoothened_path
	return [spin, thrust, false]

func count_path_dist(path):
	var sum = 0
	for i in range(0,path.size()-2):
		sum += path[i].distance_to(path[i+1])
	return sum

func calculate_ship_thrust(next_point):
	var speed_dist = (ship.position + ship.velocity).distance_to(next_point)
	var dir_to_next_point = (ship.position + ship.velocity).angle_to_point(next_point)
	var rotation = wrapf(ship.rotation, -PI, PI)  # Normalize the rotation
	dir_to_next_point = wrapf(dir_to_next_point, -PI, PI)  # Normalize the target angle
	var angle_diff = wrapf(dir_to_next_point - rotation, -PI, PI)

	var speed = ship.velocity.length()
	var dist = ship.position.distance_to(next_point)
	#if speed < 50 or (speed_dist > 10 and abs(angle_diff) < 0.005 * speed):
	if abs(angle_diff) < 0.05 and speed_dist > 10:
		return 1
	elif speed > 150 and abs(angle_diff) > PI/2:
		return 1
	else:
		return 0
	
func smoothen_path(points_path, _walls):
	var smoothened_path = [points_path[0]]
	var current_point = points_path[0]
	var last_non_intersecting_point = points_path[1]
	
	for i in range(2, points_path.size()):
		var p = points_path[i]
		var intersecting = false
		for w in _walls:
			if segment_intersects_segment_with_offset(current_point,p,w[0], w[1],ship.RADIUS):
				intersecting = true
		if intersecting == false:
			last_non_intersecting_point = p
		else:
			smoothened_path.push_back(last_non_intersecting_point)
			current_point = last_non_intersecting_point
	smoothened_path.push_back(last_non_intersecting_point)	
	smoothened_path.push_back(points_path[points_path.size()-1])
	return smoothened_path


func segment_intersects_segment_with_offset(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2, offset: float) -> bool:
	# Směrový vektor druhé úsečky
	var q_dir = (q2 - q1).normalized()

	# Kolmý vektor (pro offset)
	var perp = Vector2(-q_dir.y, q_dir.x) * ship.RADIUS
	var wall_width = 10
	var perp2 = Vector2(-q_dir.y, q_dir.x) * (ship.RADIUS + wall_width)
	
	# Vytvoření obdélníku kolem druhé úsečky
	var poly = [
		q1 + perp2 - q_dir * ship.RADIUS ,  # Levý horní roh
		q2 + perp2 + q_dir * ship.RADIUS,  # Pravý horní roh
		q2 - perp + q_dir * ship.RADIUS,  # Pravý dolní roh
		q1 - perp - q_dir * ship.RADIUS   # Levý dolní roh
	]
	
	# Kontrola průniku první úsečky s polygonem (obdélníkem)
	return is_segment_intersecting_polygon(p1, p2, poly)
	
func is_segment_intersecting_polygon(p1: Vector2, p2: Vector2, polygon: Array) -> bool:
	# Kontrola, zda úsečka protíná jakoukoli hranu polygonu
	for i in range(polygon.size()):
		var q1 = polygon[i]
		var q2 = polygon[(i + 1) % polygon.size()]
		if do_segments_intersect(p1, p2, q1, q2):
			return true
	return false

func do_segments_intersect(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var r = p2 - p1
	var s = q2 - q1
	var det = r.cross(s)
	if det == 0:
		return false
	var t = (q1 - p1).cross(s) / det
	var u = (q1 - p1).cross(r) / det
	return t >= 0 and t <= 1 and u >= 0 and u <= 1


func calculate_ship_spin(x: Node2D, y: Vector2, thrust) -> int:
	var dist = x.position.distance_to(y)
	var dir_to_next_point = (x.position + (x.velocity + Vector2.from_angle(x.rotation) * ship.ACCEL * _delta * thrust)).angle_to_point(y)
	
	var rotation = wrapf(x.rotation, -PI, PI)  # Normalize the rotation
	dir_to_next_point = wrapf(dir_to_next_point, -PI, PI)  # Normalize the target angle
	
	# Calculate the angular difference
	var angle_diff = wrapf(dir_to_next_point - rotation, -PI, PI)
	
	if abs(angle_diff) > 0.05:  # If the difference is greater than the threshold
		return -1 if angle_diff < 0 else 1
	return 0

func find_shady_andrew_closest_path(polygon_path, _polygons, start, end):
	var points_path = [end]
	var size = polygon_path.size()
	if size == 0:
		points_path.push_back(end)
		return points_path
	var current_point = end
	var current_poly = _polygons[polygon_path[size-1]]
	for i in range(1,polygon_path.size()):
		var next_poly = _polygons[polygon_path[size - 1 - i]]
		
		var intersect_point = find_shady_closest_point(ship, current_point, current_poly,next_poly)
		points_path.insert(0,intersect_point)
		current_poly = next_poly
		current_point = intersect_point
		
	points_path.insert(0,start)
	return points_path

func find_shady_closest_point(ship, current_point, current_poly,next_poly):
	var intersecting_points = []
	for cp in current_poly:
		for np in next_poly:
			if cp == np and cp not in intersecting_points:
				intersecting_points.push_back(cp)
	if intersecting_points.size() != 2:
		print("ERROR SIZE")
	
	var i_dir = (intersecting_points[1] - intersecting_points[0]).normalized()
	var i_len = intersecting_points[0].distance_to(intersecting_points[1])
	var new_x = intersecting_points[0] + i_dir * (i_len/10)
	var new_y = intersecting_points[1] - i_dir * (i_len/10)
	var mid_x = (ship.position.x + current_point.x) / 2
	var mid_y = (ship.position.y + current_point.y) / 2
	var mid_point = Vector2(mid_x,mid_y)
	
	var final_point = Geometry2D.get_closest_point_to_segment(mid_point,new_x, new_y)
	
	
	return final_point

func get_intersecting_segment(poly1,poly2):
	var intersecting_points = []
	for cp in poly1:
		for np in poly2:
			if cp == np and cp not in intersecting_points:
				intersecting_points.push_back(cp)
	if intersecting_points.size() != 2:
		print("ERROR SIZE")
	return intersecting_points
	

func find_polygon_path(start_poly, end_poly, _polygons, _neighbors):
	var queue = [start_poly]
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

func find_closest_gem(ship_actual_polygon, _gems, _polygons, _neighbors):
	var closest_gem_dist = 100000
	var result_gem = null
	for g in _gems:
		var gem_polygon = find_polygon_with_point(g, _polygons)
		var polygon_path = find_polygon_path(ship_actual_polygon, gem_polygon, _polygons, _neighbors)
		var andrew_path = find_shady_andrew_closest_path(polygon_path,_polygons,ship.position,g)
		var dist = count_path_dist(andrew_path)
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
