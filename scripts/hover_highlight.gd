extends Node2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")

const TilesetAtlas = WorldTileMapLayer.TilesetAtlas

var hovered_tile: Vector2i

@onready var world_map: WorldTileMapLayer:
	set(value):
		world_map = value
		outline.visible = world_map != null
		if world_map == null:
			return
		var half_tile_size := world_map.tile_set.tile_size / 2
		outline.points = [
			Vector2(0, half_tile_size.y),
			Vector2(half_tile_size.x, 0),
			Vector2(0, -half_tile_size.y),
			Vector2(-half_tile_size.x, 0)
		]

@onready var outline: Line2D = $Outline

func _ready() -> void:
	world_map = get_parent()

func _process(_delta: float) -> void:
	var mouse_pos := get_global_mouse_position()
	var tile_pos := world_map.mouse_to_map(mouse_pos)
	if tile_pos == hovered_tile:
		return
	position = world_map.map_to_local(tile_pos)
	hovered_tile = tile_pos
	outline.position = Vector2(0.0, 0.0)
	if world_map.get_cell_source_id(hovered_tile) == TilesetAtlas.TERRAIN:
		position.y += world_map.tile_set.tile_size.y
		outline.position.y += -20.0 - world_map.tile_set.tile_size.y # TODO no magic numbers
