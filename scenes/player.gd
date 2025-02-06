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
@export var mining_target_offset := Vector2(0, -8)
@export var minable_entity_types: Array[EntityType] = [EntityType.POWER_POLE, EntityType.LASER]

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
				laser_beam.visible = false
				laser_particles.visible = false
				laser_particles.emitting = false
			State.BUILDING:
				MessageBuss.build_mode_exited.emit()
		state = value
		match state:
			State.MINING:
				body_sprite.frame = 1 # TODO no magic numbers
				laser_beam.visible = true
				laser_particles.emitting = true
				laser_particles.visible = true
			State.BUILDING:
				MessageBuss.build_mode_entered.emit()
				


var selected_building: EntityType:
	set(value):
		if value == selected_building:
			return
		selected_building = value
		if building_preview != null:
			remove_child(building_preview)
			building_preview.queue_free()
			building_preview = null
		if selected_building == EntityType.NONE:
			return
		else:
			building_preview = entity_registry.get_entity_preview_scene(selected_building).instantiate()
			add_child(building_preview)
			update_building_preview()
		MessageBuss.set_selected_entity_type.emit(selected_building, true)

var building_preview: Node2D = null

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
var interactions:={}

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var visuals: Node2D = $Visuals
@onready var body_sprite: AnimatedSprite2D = $Visuals/Body
@onready var mining_timer: Timer = $MiningTimer
@onready var laser_spawn_point: Node2D = %LaserSpawnPoint
@onready var laser_beam: Line2D = $LaserBeam
@onready var laser_particles: GPUParticles2D = $LaserParticles

func _ready() -> void:
	for node in get_tree().get_nodes_in_group(&"terrain"):
		if node is WorldTileMapLayer:
			world_map = node
			break
	

func _process(_delta: float) -> void:
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

	var tile_offset := world_map.local_to_map(world_map.to_local(global_position)) - target_tile
	var quarter_tile_size := Vector2(world_map.tile_set.tile_size) / 4.0
	var target_face_offset: Vector2
	if tile_offset.x <= 0 and tile_offset.y <= 0:
		target_face_offset = Vector2(
			quarter_tile_size.x if absf(tile_offset.x) < absf(tile_offset.y) else -quarter_tile_size.x,
			-quarter_tile_size.y
		)
	else:
		var half_tile_size := Vector2(world_map.tile_set.tile_size) / 2.0
		var t := clampf(
			remap(
				(-target).angle_to(Vector2.DOWN),
				-PI / 3.0,
				PI / 3.0,
				0.0, 
				1.0
			),
			0.0,
			1.0
		)
		var x_offset:float = Tween.interpolate_value(
			-quarter_tile_size.x,
			half_tile_size.x,
			t,
			1.0,
			Tween.TRANS_LINEAR,
			Tween.EASE_IN_OUT
		)
		target_face_offset = Vector2(
			x_offset,
			half_tile_size.y - absf(x_offset) / 2.0
		)

	var target_pos := target + target_face_offset + mining_target_offset
	laser_beam.points = [spawn_point, target_pos]
	laser_particles.position = target_pos

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed(&"cheat"):
		iron_count += 100
		coal_count += 100

	var movement_direction = Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_up", &"move_down")
	).normalized()

	var speed := max_speed

	if Input.is_action_just_pressed(&"build_power_pole"):
		if  iron_count < entity_registry.get_entity_build_cost(EntityType.POWER_POLE):
			MessageBuss.set_selected_entity_type.emit(EntityType.POWER_POLE, false)
		else:
			state = State.BUILDING
			selected_building = EntityType.POWER_POLE
	if Input.is_action_just_pressed(&"build_laser"):
		if  iron_count < entity_registry.get_entity_build_cost(EntityType.LASER):
			MessageBuss.set_selected_entity_type.emit(EntityType.LASER, false)
		else:
			state = State.BUILDING
			selected_building = EntityType.LASER

	if Input.is_action_pressed(&"tile_map_interaction"):
		var tile := world_map.mouse_to_map(get_global_mouse_position())
		match state:
			State.IDLE:
				if is_within_interaction_range(tile) and can_mine_tile(tile):
					state = State.MINING
					target_tile = tile
					mining_timer.start()
			State.MINING:
				if target_tile != tile:
					if is_within_interaction_range(tile) and can_mine_tile(tile):
						target_tile = tile
					else:
						state = State.IDLE
				if not is_within_interaction_range(target_tile):
					state = State.IDLE
					mining_timer.stop()

				var to_target := world_map.map_to_local(target_tile) - world_map.to_local(global_position)
				if not is_zero_approx(to_target.x):
					visuals.scale.x = signf(to_target.x)

			State.BUILDING:
				if is_within_interaction_range(tile) and can_build_on_tile(tile):
					var cost := entity_registry.get_entity_build_cost(selected_building)
					if iron_count >= cost:
						iron_count -= cost
						MessageBuss.request_spawn_entity.emit(tile, selected_building)
				state = State.IDLE
				selected_building = EntityType.NONE
	elif state == State.MINING:
		state = State.IDLE
		mining_timer.stop()
	elif state == State.BUILDING:
		update_building_preview()
	
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

func get_tile_size() -> Vector2i:
	return world_map.tile_set.tile_size

func is_within_interaction_range(tile: Vector2i) -> bool:
	var tile_pos := world_map.map_to_local(tile)
	var player_pos := world_map.to_local(global_position)
	var offset := tile_pos - player_pos
	offset /= Vector2(world_map.tile_set.tile_size)
	return offset.length() <= interaction_range

func can_build_on_tile(tile: Vector2i) -> bool:
	return world_map.get_cell_source_id(tile) == -1

func can_mine_tile(tile: Vector2i) -> bool:
	match world_map.get_cell_source_id(tile):
		-1:
			return false
		WorldTileMapLayer.TilesetAtlas.TERRAIN:
			return true
		WorldTileMapLayer.TilesetAtlas.ENTITIES:
			return world_map.get_cell_alternative_tile(tile) in minable_entity_types
		_:
			assert(false, "Unknown source id")
	return false
	

func update_building_preview() -> void:
	assert(state == State.BUILDING)
	assert(selected_building != EntityType.NONE)
	if building_preview == null:
		return
	
	var tile := world_map.mouse_to_map(get_global_mouse_position())
	if not world_map.get_cell_source_id(tile) == -1:
		building_preview.visible = false
		return
	building_preview.visible = true
	building_preview.global_position = world_map.to_global(world_map.map_to_local(tile))


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

func on_body_entered_move_towards_area(body: Node2D) -> void:
	if not body.is_in_group(&"pickup"):
		return
	assert(body.has_method(&"set_target"))
	body.set_target(self)

func on_area_enter_interaction_area(area: Area2D, entered: bool) -> void:
	assert(area.has_method(&"get_interaction"))
	if entered:
		var new_interaction :Node= area.get_interaction()
		assert(new_interaction.has_method(&"interact"))
		interaction = new_interaction
		interactions[area] = new_interaction
	else:
		interactions.erase(area)
		if interactions.is_empty():
			interaction = null
		else:
			interaction = interactions.values().back()

func on_mining_timer_timeout() -> void:
	assert(state == State.MINING)
	var energy_cost := world_map.get_cell_mining_energy_cost(target_tile)
	var current_damage := world_map.get_cell_damage(target_tile)
	var damage := mining_power * mining_timer.wait_time
	if current_damage + damage >= energy_cost:
		world_map.reset_cell_damage(target_tile)
		MessageBuss.request_set_world_tile.emit(target_tile, BlockType.NONE, 0)
		state = State.IDLE
	else:
		world_map.set_cell_damage(target_tile, current_damage + damage)
