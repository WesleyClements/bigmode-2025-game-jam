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
@export var interaction_range: float = 2.5
@export var mining_power: float = 1.0
@export var laser_color: Color = Color(1, 0, 0.953125)
@export var laser_width: float = 1.5

var world_map: WorldTileMapLayer
var previous
var state: State = State.IDLE:
	set(value):
		if value == state:
			return
		match state:
			State.MINING:
				body_sprite.frame = 0 # TODO no magic numbers
				mining_timer.stop()
			State.BUILDING:
				MessageBuss.build_mode_exited.emit()
		state = value
		match state:
			State.MINING:
				body_sprite.frame = 1 # TODO no magic numbers
			State.BUILDING:
				MessageBuss.build_mode_entered.emit()

var selected_building: EntityType:
	set(value):
		if value == selected_building:
			return
		selected_building = value
		MessageBuss.set_selected_entity_type.emit(selected_building)

var target_tile: Vector2i

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
@onready var body_sprite: AnimatedSprite2D = $Visuals/Body
@onready var mining_timer: Timer = $MiningTimer
@onready var laser_spawn_point: Node2D = %LaserSpawnPoint

func _ready() -> void:
	for node in get_tree().get_nodes_in_group(&"terrain"):
		if node is WorldTileMapLayer:
			world_map = node
			break

func _draw():
	if state != State.MINING:
		return
	var spawn_point := to_local(laser_spawn_point.global_position)
	var target := to_local(world_map.to_global(world_map.map_to_local(target_tile)))
	var offset := (target - spawn_point)
	const SLOPE_THRESHOLD = 0.5
	if not is_zero_approx(offset.x) and absf(offset.y) / absf(offset.x) > SLOPE_THRESHOLD:
		const STEEP_SLOPE_OFFSET = Vector2(0.5, 0.5)
		spawn_point.x += signf(offset.x) * STEEP_SLOPE_OFFSET.x
		spawn_point.y += -signf(offset.y) * STEEP_SLOPE_OFFSET.y
	draw_line(
		spawn_point,
		to_local(world_map.to_global(world_map.map_to_local(target_tile))),
		laser_color,
		laser_width
	)
		
func _physics_process(delta: float) -> void:
	if Input.is_action_pressed(&"give_coal"):
		coal_count += 1
	if Input.is_action_pressed(&"give_iron"):
		iron_count += 1

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
			State.IDLE:
				if is_within_interaction_range(tile) and can_mine_tile(tile):
					state = State.MINING
					target_tile = tile
					var energy_cost := world_map.get_cell_energy_cost(tile)
					mining_timer.wait_time = energy_cost / mining_power
					mining_timer.start()
			State.MINING:
				# if target_tile != tile:
				# 	if is_within_interaction_range(tile) and can_mine_tile(tile):
				# 		mining_timer.stop()
				# 		target_tile = tile
				# 		var energy_cost := world_map.get_cell_energy_cost(tile)
				# 		mining_timer.wait_time = energy_cost / mining_power
				# 		mining_timer.start()
				# 	else:
				# 		state = State.IDLE
				if not is_within_interaction_range(target_tile):
					state = State.IDLE
					mining_timer.stop()

				var to_target := world_map.map_to_local(target_tile) - world_map.to_local(global_position)
				if not is_zero_approx(to_target.x):
					visuals.scale.x = signf(to_target.x)

			State.BUILDING:
				if is_within_interaction_range(tile):
					var cost := entity_registry.get_entity_cost(selected_building)
					if iron_count >= cost:
						iron_count -= cost
						MessageBuss.request_spawn_entity.emit(tile, selected_building)
					state = State.IDLE
					selected_building = EntityType.NONE
	elif state == State.MINING:
		state = State.IDLE
		mining_timer.stop()
	
	if Input.is_action_pressed(&"interact") and interaction != null:
		interaction.interact(self, Input.is_action_just_pressed(&"interact"))

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

	if not is_zero_approx(movement_direction.x) and state != State.MINING:
		visuals.scale.x = signf(movement_direction.x)

	move_and_slide()

func is_within_interaction_range(tile: Vector2i) -> bool:
	var tile_pos := world_map.map_to_local(tile)
	var player_pos := world_map.to_local(global_position)
	var offset := tile_pos - player_pos
	offset /= Vector2(world_map.tile_set.tile_size)
	return offset.length() <= interaction_range

func can_mine_tile(tile: Vector2i) -> bool:
	return world_map.get_cell_source_id(tile) == WorldTileMapLayer.TilesetAtlas.TERRAIN


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

func on_mining_timer_timeout() -> void:
	assert(state == State.MINING)
	MessageBuss.request_set_world_tile.emit(target_tile, BlockType.NONE, 0)
	state = State.IDLE