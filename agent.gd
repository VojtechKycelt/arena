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
	
	var ship_actual_polygon = find_polygon_with_point(ship.position,_polygons)
	var gem_polygon = find_polygon_with_point(_gems[0], _polygons)
	if ship_actual_polygon.value == null or gem_polygon.value == null:
		return [spin, thrust, false]
	
	var path = find_polygon_path(ship_actual_polygon, gem_polygon, _polygons, _neighbors)
	var points_path = find_closest_path(path, _polygons, ship.position, _gems[0])
	debug_path.points = points_path
	debug_path.default_color = Color.MAROON
	
	#1. turn ship to poimt
	var next_point = points_path[1]
	spin = calculate_ship_spin(ship,points_path[1])
	
	var dist = ship.position.distance_to(next_point)
	if (dist > 30):
		thrust = 1
	else:
		thrust = 0
	return [spin, thrust, false]

func calculate_ship_spin(x: Node2D, y: Vector2) -> int:
	var dir_to_next_point = x.position.angle_to_point(y)
	if x.rotation > dir_to_next_point + 0.1 or x.rotation < dir_to_next_point - 0.1:
		if dir_to_next_point > x.rotation:
			return 1
		else:
			return -1
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
	#path.insert(0,start_index)
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

# Called every time the agent has bounced off a wall.
func bounce():
	return

# Called every time a gem has been collected.
func gem_collected():
	return
