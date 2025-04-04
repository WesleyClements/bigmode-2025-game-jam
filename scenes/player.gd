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

signal item_count_updated(item_type: ItemType, count: float)
signal set_selected_entity_type(entity_type: EntityType, successful: bool)

@export var entity_registry: EntityRegistry
@export var max_speed: float = 70.0
@export var speed_up_time: float = 0.1
@export var slow_down_time: float = 0.1
@export var interaction_range: float = 2.5
@export var mining_power: float = 1.0
@export var mining_target_offset := Vector2(0, -8)
@export var minable_entity_types: Array[EntityType] = [EntityType.POWER_POLE, EntityType.LASER]
@export_flags_2d_physics var los_collision_mask: int = 0b1

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
		if selected_building != EntityType.NONE:
			var building_preview_template := entity_registry.get_entity_preview_scene(selected_building)
			var building_preview = building_preview_template.instantiate()
			world_map.add_child(building_preview)
		set_selected_entity_type.emit(selected_building, true)

var target_tile: Vector2i

var coal_count := 0.0:
	set(value):
		assert(value >= 0.0)
		coal_count = value
		item_count_updated.emit(ItemType.COAL, coal_count)
var iron_count := 0.0:
	set(value):
		assert(value >= 0.0)
		iron_count = value
		item_count_updated.emit(ItemType.IRON, iron_count)

var interaction: Node = null
var interactions:={}

var collision_point:Vector2

@onready var world_map: WorldTileMapLayer = get_parent()
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var visuals: Node2D = $Visuals
@onready var body_sprite: AnimatedSprite2D = $Visuals/Body
@onready var mining_timer: Timer = $MiningTimer
@onready var laser_spawn_point: Node2D = %LaserSpawnPoint
@onready var laser_beam: Line2D = $LaserBeam
@onready var laser_particles: GPUParticles2D = $LaserParticles
@onready var item_pickup_sound: AudioStreamPlayer2D = $ItemPickupSound

func _process(_delta: float) -> void:
	if state != State.MINING:
		return
	var spawn_point := to_local(laser_spawn_point.global_position)
	var target_pos := to_local(collision_point) + mining_target_offset
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
			set_selected_entity_type.emit(EntityType.POWER_POLE, false)
		else:
			state = State.BUILDING
			selected_building = EntityType.POWER_POLE
	if Input.is_action_just_pressed(&"build_laser"):
		if  iron_count < entity_registry.get_entity_build_cost(EntityType.LASER):
			set_selected_entity_type.emit(EntityType.LASER, false)
		else:
			state = State.BUILDING
			selected_building = EntityType.LASER

	if Input.is_action_pressed(&"tile_map_interaction"):
		var tile := world_map.mouse_to_map(get_global_mouse_position())
		match state:
			State.IDLE when Input.is_action_just_pressed(&"tile_map_interaction") \
				and is_within_interaction_range(tile) \
				and can_mine_tile(tile) \
				and is_in_los(tile):
				state = State.MINING
				target_tile = tile
				mining_timer.start()
			State.IDLE when world_map.get_cell_source_id(tile) != WorldTileMapLayer.TilesetAtlas.ENTITIES \
				and is_within_interaction_range(tile) \
				and can_mine_tile(tile) \
				and is_in_los(tile):
				state = State.MINING
				target_tile = tile
				mining_timer.start()

			State.MINING:
				if target_tile != tile:
					if is_within_interaction_range(tile) and can_mine_tile(tile) and is_in_los(tile):
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

	var motion := velocity * delta
	for i:int in range(4):
		var collision := move_and_collide(motion, false, safe_margin, false)
		if not collision:
			break
		var normal := collision.get_normal()
		var tangent := Vector2(-normal.y, normal.x) # Rotate 90 degrees
		var remainder := collision.get_remainder()
		if remainder.dot(tangent) < 0:
			tangent = -tangent

		motion = tangent * remainder.length()


func get_coal_count() -> float:
	return coal_count

func get_iron_count() -> float:
	return iron_count

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

func is_in_los(tile: Vector2i, space_state:=get_world_2d().direct_space_state) -> bool:
	var tile_pos := world_map.to_global(world_map.map_to_local(tile))
	if test_ray_cast_to_terrain(tile, tile_pos, tile_pos, space_state):
		return true
	
	var tile_offset := world_map.local_to_map(world_map.to_local(global_position)) - tile
	if tile_offset.x == 0 or tile_offset.y == 0:
		return false

	var quarter_tile_size := Vector2(world_map.tile_set.tile_size) / 4.0
	if tile_offset.x > 0:
		if test_ray_cast_to_terrain(tile, tile_pos, tile_pos + Vector2(quarter_tile_size.x, quarter_tile_size.y), space_state):
			return true
	else:
		if test_ray_cast_to_terrain(tile, tile_pos, tile_pos + Vector2(-quarter_tile_size.x, -quarter_tile_size.y), space_state):
			return true
	if tile_offset.y > 0:
		if test_ray_cast_to_terrain(tile, tile_pos, tile_pos + Vector2(-quarter_tile_size.x, quarter_tile_size.y), space_state):
			return true
	else:
		if test_ray_cast_to_terrain(tile, tile_pos, tile_pos + Vector2(quarter_tile_size.x, -quarter_tile_size.y), space_state):
			return true
	return false

func test_ray_cast_to_terrain(tile: Vector2i, tile_pos: Vector2, target: Vector2, space_state: PhysicsDirectSpaceState2D) -> bool:
	if not space_state:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, target, los_collision_mask)
	var result := space_state.intersect_ray(query)
	if not result:
		collision_point = target
		return true
	var nudge := (tile_pos - Vector2(result.position)).normalized()
	if world_map.local_to_map(world_map.to_local(result.position + nudge)) != tile:
		return false
	collision_point = result.position
	return true


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
	item_pickup_sound.play()

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
