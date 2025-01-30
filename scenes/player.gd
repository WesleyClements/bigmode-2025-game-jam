extends CharacterBody2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")

const ItemType = MessageBuss.ItemType
const BlockType = MessageBuss.BlockType
const EntityType = MessageBuss.EntityType

enum State {
	IDLE,
	MINING,
	BUILDING,
}

@export var entity_registry: EntityRegistry
@export var max_speed: float = 70.0
@export var speed_up_time: float = 0.1
@export var slow_down_time: float = 0.1
@export var interaction_range: float = 2.0

var world_map: WorldTileMapLayer
var previous
var state: State = State.IDLE
var selected_building: EntityType:
	set(value):
		if value == selected_building:
			return
		selected_building = value
		MessageBuss.set_selected_entity_type.emit(selected_building)

var coal_count := 0.0:
	set(value):
		coal_count = value
		MessageBuss.item_count_updated.emit(ItemType.COAL, coal_count)
var iron_count := 0.0:
	set(value):
		iron_count = value
		MessageBuss.item_count_updated.emit(ItemType.IRON, iron_count)

var interaction: Node = null

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var visuals: Node2D = $Visuals

func _ready() -> void:
	for node in get_tree().get_nodes_in_group(&"terrain"):
		if node is WorldTileMapLayer:
			world_map = node
			break

func _draw():
	var player_tile := world_map.local_to_map(world_map.to_local(global_position))
	var center := to_local(world_map.to_global(world_map.map_to_local(player_tile)))
	var offset := world_map.tile_set.tile_size * (interaction_range + 0.5)
	draw_polyline([center + Vector2(0, offset.y), center + Vector2(offset.x, 0), center + Vector2(0, -offset.y), center + Vector2(-offset.x, 0), center + Vector2(0, offset.y)], Color(1, 1, 1, 0.5), 1)

		
func _physics_process(delta: float) -> void:
	queue_redraw()
	var movement_direction = Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_up", &"move_down")
	).normalized()

	var speed := max_speed

	if Input.is_action_just_pressed(&"build_power_pole") and iron_count >= entity_registry.get_entity_cost(EntityType.POWER_POLE):
		state = State.BUILDING
		selected_building = EntityType.POWER_POLE
	elif Input.is_action_just_pressed(&"build_laser") and iron_count >= entity_registry.get_entity_cost(EntityType.LASER):
		state = State.BUILDING
		selected_building = EntityType.LASER
	elif Input.is_action_pressed(&"tile_map_interaction"):
		var tile := world_map.mouse_to_map(get_global_mouse_position())
		match state:
			State.IDLE when Input.is_action_just_pressed(&"tile_map_interaction"):
				var player_tile := world_map.local_to_map(world_map.to_local(global_position))
				var tile_offset := (tile - player_tile).abs()
				if tile_offset.x <= interaction_range and tile_offset.y <= interaction_range and world_map.get_cell_source_id(tile) == WorldTileMapLayer.TilesetAtlas.TERRAIN:
					state = State.MINING
			State.MINING:
				MessageBuss.request_set_world_tile.emit(tile, BlockType.NONE, 0)
				state = State.IDLE
			State.BUILDING:
				var cost := entity_registry.get_entity_cost(selected_building)
				if iron_count >= cost:
					iron_count -= cost
					MessageBuss.request_spawn_entity.emit(tile, selected_building)
				state = State.IDLE
				selected_building = EntityType.NONE
	elif state == State.MINING:
		state = State.IDLE
	
	if Input.is_action_just_pressed(&"interact") and interaction != null:
		interaction.interact(self)

	if not movement_direction.is_zero_approx():
		animation_tree["parameters/conditions/is_idle"] = false
		animation_tree["parameters/conditions/is_moving"] = true
		if velocity.length() < max_speed:
			velocity = velocity.move_toward(movement_direction * speed, speed * delta / speed_up_time)
		else:
			velocity = movement_direction * speed

	elif not velocity.is_zero_approx():
		velocity = velocity.move_toward(Vector2(), max_speed * delta / slow_down_time)
	else:
		animation_tree["parameters/conditions/is_idle"] = true
		animation_tree["parameters/conditions/is_moving"] = false

	if not is_zero_approx(movement_direction.x):
		visuals.scale.x = -signf(movement_direction.x)

	move_and_slide()


func on_body_entered_pickup_area(body: Node2D) -> void:
	if not body.is_in_group(&"pickup"):
		return
	assert(body.has_method(&"collect"))
	assert(body.has_method(&"get_type"))
	assert(body.has_method(&"get_amount"))
	body.collect()
	var type = body.get_type()
	match type:
		ItemType.COAL:
			coal_count += body.get_amount()
		ItemType.IRON:
			iron_count += body.get_amount()

func on_area_enter_interaction_area(area: Area2D) -> void:
	assert(area.has_method(&"get_interaction"))
	interaction = area.get_interaction()
	assert(interaction.has_method(&"interact"))