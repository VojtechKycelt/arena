extends Node2D

@onready var ship = get_parent()
@onready var debug_path = ship.get_node('../debug_path')


var ticks = 0
var spin = 0
var thrust = false


# This method is called on every tick to choose an action.  See README.md
# for a detailed description of its arguments and return value.
func action(_walls: Array[PackedVector2Array], _gems: Array[Vector2], 
			_polygons: Array[PackedVector2Array], _neighbors: Array[Array]):
	debug_path.default_color = Color.MAROON
	debug_path.width = 7

	#Tips and tricks
	#DONE 1. find out in which navmesh polygon we are
	#DONE	-may happen we are not in a navmesh, lets randomly thrust
	#2. search through polygons and find polygons with gems
	#3. if we do a Dijkstra we can compute costs with centroids or better we can 
	#find closest point in polygon a
	#4. use debug_path to debug our path
	#5. follow the path - seek / arrive / follow from prev classes
	#		watchout we need to turn to brake / thrust backwards
	
	#ticks += 1
	#if ticks % 15 == 0:
	#	spin = randi_range(-1, 1)
	#	thrust = bool(randi_range(0, 1))
	
	#TODO select gem only once and then after it is collected to new one so ship does not switch
	#TODO Funnel algorithm of path
	var selected_gem = find_closest_gem(_gems)
	var ship_actual_polygon = find_polygon_with_point(ship.position,_polygons)
	var gem_polygon = find_polygon_with_point(selected_gem, _polygons)
	if ship_actual_polygon.value == null or gem_polygon.value == null:
		return [spin, thrust, false]
	
	var polygon_path = find_polygon_path(ship_actual_polygon, gem_polygon, _polygons, _neighbors)
	
	var points_path = find_closest_path(polygon_path, _polygons, ship.position, selected_gem)
	#debug_path.points = points_path
	
	
	#1. turn ship to point
	#var next_point = points_path[1]
	spin = calculate_ship_spin2(ship,points_path[1])
	#print(get_intersecting_walls(selected_gem,_walls))
	#var dist = ship.position.distance_to(next_point)
	#print(ship.velocity)
	
	var funnel_path = find_funnel_path(polygon_path, _polygons, selected_gem)
	funnel_path.insert(0,ship.position)
	debug_path.points = funnel_path
	print("funnel_path")
	print(funnel_path)

	if spin == 0:
		thrust = 1
	else:
		thrust = 0
	thrust = 0
	#spin = 1
	#print("ship_rotation: " + str(ship.rotation))

	
	return [spin, thrust, false]

func find_funnel_path(polygon_path, _polygons, selected_gem):
	var pivot_points = []
	var intersect_points = []
	if polygon_path.size() < 2:
		pivot_points.push_back(selected_gem)
		return pivot_points
	
	#TODO WHILE CYCLE
	for p1 in _polygons[polygon_path[0]]:
		for p2 in _polygons[polygon_path[1]]:
			if p1 == p2 and not p1 in intersect_points:
				intersect_points.push_back(p1)
	
	var a1 = ship.position.angle_to(intersect_points[0])
	var a2 = ship.position.angle_to(intersect_points[1])
	var left_point
	var right_point
	if (angle_difference_radians(a1,a2) > 0):
		left_point = intersect_points[0]
		right_point = intersect_points[1]
	else:
		left_point = intersect_points[1]
		right_point = intersect_points[0]

	

	return intersect_points

func normalize_angle_radians(angle: float) -> float:
	angle = fmod(angle + PI, 2 * PI)
	if angle < -PI:
		angle += 2 * PI
	return angle
	
func angle_difference_radians(angle1: float, angle2: float) -> float:
	var diff = normalize_angle_radians(angle2) - normalize_angle_radians(angle1)
	if diff > PI:
		diff -= 2 * PI
	elif diff < -PI:
		diff += 2 * PI
	return diff

func calculate_ship_spin(x: Node2D, y: Vector2) -> int:
	#var dir_to_next_point = (x.position + x.velocity).angle_to_point(y)
	var dir_to_next_point = x.position.angle_to_point(y)

	#print(dir_to_next_point)
	#print("x.rotation: " + str(x.rotation))
	
	if x.rotation > dir_to_next_point + 0.05 or x.rotation < dir_to_next_point - 0.05:
		if dir_to_next_point < x.rotation or dir_to_next_point > x.rotation:
			return -1
		else:
			return 1
	return 0
	
func calculate_ship_spin2(x: Node2D, y: Vector2) -> int:
	var dir_to_next_point = (x.position + x.velocity).angle_to_point(y)
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
	
	var current_point = start
	for pi in polygon_path:
		var next_poly = _polygons[pi]
		var next_point = find_closest_point_between_point_and_polygon(current_point,next_poly)
		#var next_point = next_poly[0]
		points_path.push_back(next_point)
		current_point = next_point
	
	#points_path.push_back(next_point)
	points_path.push_back(end)
	return points_path
	
func find_closest_point_between_point_and_polygon(start, polygon):
	var closest_dist = 10000
	var closest_point = start
	for i in range(polygon.size()-1):
		var p1 = polygon[i]
		var p2 = polygon[i+1]
		
		var point = Geometry2D.get_closest_point_to_segment(start, p1, p2)
		var dist = point.distance_to(start)
		if  dist < closest_dist:
			closest_dist = dist
			closest_point = point
	return closest_point
	

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
	
	print("FAIL")
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

func get_intersecting_walls(selected_gem, _walls):
	#not working yet
	var dir_to_gem = ship.position.direction_to(selected_gem)
	var dir_to_ship = selected_gem.direction_to(ship.position)
	var dist_to_gem = ship.position.distance_to(selected_gem)
	var walls_intersecting = []
	for w in _walls:
		var dir = w[0].direction_to(w[1])
		var dist = w[0].distance_to(w[1])
		var intersect_point = Geometry2D.line_intersects_line(ship.position,dir_to_gem,w[0], dir)
		if intersect_point == null:
			continue
		if is_between(w[0],w[1], intersect_point):
			walls_intersecting.push_back(w.duplicate())
	return walls_intersecting

func is_between(a,c,b):
	var d1 = a.distance_to(c)
	var d2 = b.distance_to(c)
	var d3 = a.distance_to(b)
	var epsilon = 2
	return d1+d2 == d3
	return d1 + d2 > d3 - epsilon and d1 + d2 < d3 + epsilon
# Called every time the agent has bounced off a wall.
func bounce():
	return

# Called every time a gem has been collected.
func gem_collected():
	return
