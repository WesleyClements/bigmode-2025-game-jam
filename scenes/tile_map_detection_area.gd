@tool
extends Node2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")

@export var root_node: Node2D
@export var detection_distance := 4
@export var outline_color := Color(1, 1, 0.0, 0.5)


@onready var world_map: WorldTileMapLayer = null if Engine.is_editor_hint() else root_node.get_parent()
@onready var area_outline: Line2D = $AreaOutline

func _ready() -> void:
	if not root_node:
		root_node = owner
	area_outline.default_color = outline_color
	var tile_size := get_tile_size()
	var x := (detection_distance + 0.5) * tile_size.x
	var y := (detection_distance + 0.5) * tile_size.y
	area_outline.points = [Vector2(0, y), Vector2(x, 0), Vector2(0, -y), Vector2(-x, 0)]

func get_tile_size() -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(32, 16) # TODO no magic numbers
	return world_map.tile_set.tile_size

func is_within_detection_distance(pos: Vector2) -> bool:
	var offset := root_node.global_position - pos
	var tile_offset := world_map.local_to_map(world_map.to_local(offset)).abs()
	return tile_offset.x <= detection_distance and tile_offset.y <= detection_distance

func find_tiles(predicate: Callable) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(-detection_distance, detection_distance + 1):
		for y in range(-detection_distance, detection_distance + 1):
			if predicate.call(world_map, Vector2i(x, y)):
				tiles.append(Vector2i(x, y))
	return tiles

func find_scenes() -> Array[Node]:
	var tile_origin := world_map.local_to_map(world_map.to_local(root_node.global_position))
	var scenes: Array[Node] = []
	for x in range(-detection_distance, detection_distance + 1):
		for y in range(-detection_distance, detection_distance + 1):
			var scene := world_map.get_cell_scene(tile_origin + Vector2i(x, y))
			if scene:
				scenes.append(scene)
	return scenes

func find_closest_tiles(predicate: Callable) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for distance in range(1, detection_distance + 1):
		if predicate.call(world_map, Vector2i(0, distance)):
			tiles.append(Vector2i(0, distance))
		if predicate.call(world_map, Vector2i(distance, 0)):
			tiles.append(Vector2i(distance, 0))
		if predicate.call(world_map, Vector2i(0, -distance)):
			tiles.append(Vector2i(0, -distance))
		if predicate.call(world_map, Vector2i(-distance, 0)):
			tiles.append(Vector2i(-distance, 0))
		
		if tiles.size() > 0:
			break
			
		for offset in range(1, distance):
			if predicate.call(world_map, Vector2i(offset, distance)):
				tiles.append(Vector2i(offset, distance))
			if predicate.call(world_map, Vector2i(-offset, distance)):
				tiles.append(Vector2i(-offset, distance))
			if predicate.call(world_map, Vector2i(offset, -distance)):
				tiles.append(Vector2i(offset, -distance))
			if predicate.call(world_map, Vector2i(-offset, -distance)):
				tiles.append(Vector2i(-offset, -distance))
			if predicate.call(world_map, Vector2i(distance, offset)):
				tiles.append(Vector2i(distance, offset))
			if predicate.call(world_map, Vector2i(distance, -offset)):
				tiles.append(Vector2i(distance, -offset))
			if predicate.call(world_map, Vector2i(-distance, offset)):
				tiles.append(Vector2i(-distance, offset))
			if predicate.call(world_map, Vector2i(-distance, -offset)):
				tiles.append(Vector2i(-distance, -offset))
			if tiles.size() > 0:
				break
		
		if tiles.size() > 0:
			break

		if predicate.call(world_map, Vector2i(distance, distance)):
			tiles.append(Vector2i(distance, distance))
		if predicate.call(world_map, Vector2i(distance, -distance)):
			tiles.append(Vector2i(distance, -distance))
		if predicate.call(world_map, Vector2i(-distance, distance)):
			tiles.append(Vector2i(-distance, distance))
		if predicate.call(world_map, Vector2i(-distance, -distance)):
			tiles.append(Vector2i(-distance, -distance))
		
		if tiles.size() > 0:
			break
	return tiles
