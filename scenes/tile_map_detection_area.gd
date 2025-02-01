@tool
extends TileAreaOutline

@onready var world_map: WorldTileMapLayer = null if Engine.is_editor_hint() else root_node.get_parent()

func get_tile_size() -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(32, 16) # TODO no magic numbers
	return world_map.tile_set.tile_size

func get_tile_origin() -> Vector2i:
	return world_map.local_to_map(world_map.to_local(root_node.global_position))

func is_within_detection_distance(pos: Vector2) -> bool:
	var tile_origin := get_tile_origin()
	var tile_position := world_map.local_to_map(world_map.to_local(pos))
	var tile_offset := (tile_position - tile_origin).abs()
	return tile_offset.x <= tile_radius and tile_offset.y <= tile_radius

func find_tiles(predicate: Callable) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(-tile_radius, tile_radius + 1):
		for y in range(-tile_radius, tile_radius + 1):
			if predicate.call(world_map, Vector2i(x, y)):
				tiles.append(Vector2i(x, y))
	return tiles

func find_scenes() -> Array[Node]:
	var tile_origin := get_tile_origin()
	var scenes: Array[Node] = []
	for x in range(-tile_radius, tile_radius + 1):
		for y in range(-tile_radius, tile_radius + 1):
			var scene := world_map.get_cell_scene(tile_origin + Vector2i(x, y))
			if scene:
				scenes.append(scene)
	return scenes

func find_closest_tiles(predicate: Callable) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for distance in range(1, tile_radius + 1):
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
