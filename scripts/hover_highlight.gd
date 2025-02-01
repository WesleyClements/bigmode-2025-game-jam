extends Node2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const Player = preload("res://scenes/player.gd")

const TilesetAtlas = WorldTileMapLayer.TilesetAtlas

@export var too_far_color: Color = Color(1.0, 0.0, 0.0)

var hovered_tile: Vector2i
var outline_color: Color

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

@onready var players: Array[Node]

@onready var outline: Line2D = $Outline

func _ready() -> void:
	world_map = get_parent()
	players = get_tree().get_nodes_in_group(&"player")
	outline_color = outline.default_color
	too_far_color.a = outline_color.a

func _process(_delta: float) -> void:
	var mouse_pos := get_global_mouse_position()
	var tile_pos := world_map.mouse_to_map(mouse_pos)
	
	update_hover_position(tile_pos)
	outline.default_color = too_far_color
	for player: Player in players:
		if not player.is_within_interaction_range(tile_pos):
			continue
		outline.default_color = outline_color
		break

func update_hover_position(tile_pos: Vector2i) -> void:
	if tile_pos == hovered_tile:
		return
	notify_hover_exit(hovered_tile)
	position = world_map.map_to_local(tile_pos)
	hovered_tile = tile_pos
	outline.position = Vector2(0.0, 0.0)
	if world_map.get_cell_source_id(hovered_tile) == TilesetAtlas.TERRAIN:
		position.y += world_map.tile_set.tile_size.y
		outline.position.y += -20.0 - world_map.tile_set.tile_size.y # TODO no magic numbers
	else:
		notify_hover_enter(hovered_tile)

func notify_hover_enter(tile_pos: Vector2i) -> void:
	var scene := world_map.get_cell_scene(tile_pos)
	if scene == null:
		return
	if not scene.has_signal(&"hover_entered"):
		return
	scene.hover_entered.emit()

func notify_hover_exit(tile_pos: Vector2i) -> void:
	var scene := world_map.get_cell_scene(tile_pos)
	if scene == null:
		return
	if not scene.has_signal(&"hover_exited"):
		return
	scene.hover_exited.emit()