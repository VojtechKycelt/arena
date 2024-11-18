extends Node2D

@onready var ship = get_parent()
@onready var debug_path = ship.get_node('../debug_path')
@onready var debug_starting_polygon = ship.get_node('../debug_path')
@onready var debug_gem_polygon = ship.get_node('../debug_path')


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
	
	var ship_actual_polygon = find_polygon_with_point(ship.position,_polygons)
	if ship_actual_polygon == null:
		spin = randi_range(-1, 1)
		thrust = bool(randi_range(0, 1))
		return [spin, thrust, false]
	debug_starting_polygon.points = ship_actual_polygon
	debug_starting_polygon.default_color = Color.RED		
	debug_starting_polygon.width = 10
	
	
	var gem_polygon = find_polygon_with_point(_gems[0], _polygons)
	if (gem_polygon == null):
		printerr("SOMETHING IS WRONG NO GEM FOUND")
		
	
	

	
	# This is a dummy agent that just moves around randomly.
	# Replace this code with your actual implementation.
	ticks += 1
	if ticks % 15 == 0:
		spin = randi_range(-1, 1)
		thrust = bool(randi_range(0, 1))
	
	
	return [spin, thrust, false]
	return [0, 0, false]
	
func find_polygon_with_point(point: Vector2, _polygons: Array[PackedVector2Array]):
	var result_polygon = null
	for polygon in _polygons:
		if Geometry2D.is_point_in_polygon(point,polygon):
			result_polygon = polygon
			result_polygon.append(polygon[0])
			break
	return result_polygon

# Called every time the agent has bounced off a wall.
func bounce():
	return

# Called every time a gem has been collected.
func gem_collected():
	return
