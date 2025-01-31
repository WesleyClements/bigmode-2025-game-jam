extends StaticBody2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const TileMapDetectionArea = preload("res://scenes/tile_map_detection_area.gd")

@export var weasel_template: PackedScene

@onready var world_map: WorldTileMapLayer = get_parent()
@onready var tile_map_detection_area: TileMapDetectionArea = $TileMapDetectionArea
@onready var spawn_timer: Timer = $SpawnTimer

func is_valid_spawn_position(tile_map: WorldTileMapLayer, offset: Vector2i, origin: Vector2i) -> bool:
	return tile_map.get_cell_source_id(origin + offset) == -1

func on_spawn_timer_timeout() -> void:
	var origin := world_map.local_to_map(world_map.to_local(global_position))
	var tiles := tile_map_detection_area.find_tiles(is_valid_spawn_position.bind(origin))
	var selected_tile := tiles[randi_range(0, tiles.size() - 1)]
	var weasel: Node2D = weasel_template.instantiate()
	weasel.global_position = world_map.to_global(world_map.map_to_local(origin + selected_tile))
	world_map.add_child(weasel)
