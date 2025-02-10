extends Node2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")

const EntityType = MessageBuss.EntityType

@export var entity_type: EntityType

var world_map: WorldTileMapLayer

func _enter_tree() -> void:
	world_map = get_parent()
	assert(world_map is WorldTileMapLayer)

func _ready() -> void:
	assert(entity_type != EntityType.NONE)
	visible = false
	MessageBuss.set_selected_entity_type.connect(on_set_selected_entity_type)

func _physics_process(_delta: float) -> void:
	var tile := world_map.mouse_to_map(get_global_mouse_position())
	print(tile)
	if world_map.get_cell_source_id(tile) != -1:
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
