extends Node2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const Player = preload("res://scenes/player.gd")

const EntityType = MessageBuss.EntityType

@export var entity_type: EntityType

var world_map: WorldTileMapLayer
var player: Player

func _enter_tree() -> void:
	world_map = get_parent()
	assert(world_map is WorldTileMapLayer)

func _ready() -> void:
	assert(entity_type != EntityType.NONE)
	visible = false
	var players := get_tree().get_nodes_in_group(&"player")
	assert(players.size() == 1)
	player = players[0]
	assert(player != null)
	player.set_selected_entity_type.connect(on_set_selected_entity_type)

func _physics_process(_delta: float) -> void:
	var tile := world_map.mouse_to_map(get_global_mouse_position())
	if not player.can_build_on_tile(tile) or not player.is_within_interaction_range(tile):
		visible = false
		return
	visible = true
	position = world_map.map_to_local(tile)

func get_tile_size() -> Vector2i:
	return world_map.tile_set.tile_size

func on_set_selected_entity_type(type: EntityType, successful: bool) -> void:
	if entity_type == type:
		return
	if not successful:
		return
	queue_free()
