extends StaticBody2D

const MAX_INT := 9223372036854775807

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const TileMapDetectionArea = preload("res://scenes/tile_map_detection_area.gd")
const GerbilGenerator = preload("res://scenes/machines/gerbil_generator.gd")

enum State {
	IDLE,
	MINING
}

signal power_pole_connected(pole: Node)
signal power_pole_disconnected(pole: Node)
signal hover_entered()
signal hover_exited()

@export var minable_tileset_atlas_ids: PackedInt32Array = [0]
@export var mineable_tileset_atlas_coords: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 3), Vector2i(2, 3)]
@export var mining_power: float = 2.0
@export var fuel_consumption_rate := 1.0
@export var target_offset := Vector2(0, -10)

var source: Node
var generator: GerbilGenerator
var separation_from_source := MAX_INT
var attached_poles := []

var powered: bool = false:
	set(value):
		if powered == value:
			return
		reset_laser_head()
		animation_player.play(&"power_up" if value else &"power_down")
		if not value:
			powered = false
			state = State.IDLE
			cool_down_timer.stop()
			queue_redraw()
		else:
			powered = true

var state := State.IDLE:
	set(value):
		if state == value:
			return
		match state:
			State.MINING:
				mining_timer.stop()
				laser_beam.visible = false
				laser_particles.visible = false
				laser_particles.emitting = false
		state = value
		match state:
			State.MINING:
				mining_timer.start()
				laser_beam.visible = true
				laser_particles.emitting = true
				laser_particles.visible = true

var target_tile_offset: Vector2i

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var world_map: WorldTileMapLayer = get_parent()
@onready var tile_map_detection_area: TileMapDetectionArea = $TileMapDetectionArea
@onready var laser_head: Node2D = $Laser/LaserHead
@onready var fire_point: Marker2D = $Laser/LaserHead/FirePoint
@onready var laser_beam: Node2D = $LaserBeam
@onready var laser_particles: GPUParticles2D = $LaserParticles
@onready var cool_down_timer: Timer = $CoolDownTimer
@onready var mining_timer: Timer = $MiningTimer

func _exit_tree() -> void:
	for pole in attached_poles:
		if pole == null:
			continue
		pole.powered_changed.disconnect(on_power_pole_powered_changed)
	attached_poles.clear()
	power_pole_connected.disconnect(on_power_pole_connected)
	power_pole_disconnected.disconnect(on_power_pole_disconnected)


func _ready():
	power_pole_connected.connect(on_power_pole_connected)
	power_pole_disconnected.connect(on_power_pole_disconnected)

	hover_entered.connect(on_hover_changed.bind(true))
	hover_exited.connect(on_hover_changed.bind(false))

func reset_laser_head() -> void:
	laser_head.rotation = 0.0
	laser_head.position.y = 0.0
	laser_head.scale = Vector2.ONE

func is_valid_mining_target(tile_map: WorldTileMapLayer, tile_offset: Vector2i, tile_origin: Vector2i) -> bool:
	var tile_pos := tile_origin + tile_offset
	if not tile_map.get_cell_source_id(tile_pos) in minable_tileset_atlas_ids:
		return false
	return tile_map.get_cell_atlas_coords(tile_pos) in mineable_tileset_atlas_coords

func find_source(pole: Node) -> Array:
	assert(not pole == null)
	assert(pole.is_in_group(&"machines"))
	assert(pole.has_method(&"get_source"))
	var separation := 1
	var node := pole
	const MAX_ITERATIONS := 100
	var i := 0
	while node != null and node != node.get_source() and i < MAX_ITERATIONS:
		node = node.get_source()
		separation += 1
		i += 1
	if node == null or i == MAX_ITERATIONS:
		return [null, MAX_INT]
	assert(node is GerbilGenerator)
	return [node, separation]

func update_source() -> void:
	source = null
	generator = null
	separation_from_source = MAX_INT

	for attached_pole in attached_poles:
		if not attached_pole.get_powered():
			continue
		var result := find_source(attached_pole)
		if result[1] >= separation_from_source:
			continue
		source = attached_pole
		generator = result[0]
		separation_from_source = result[1]

func on_power_pole_connected(pole: Node) -> void:
	assert(not pole == null)
	assert(pole.is_in_group(&"machines"))
	assert(pole.has_method(&"get_powered"))
	assert(pole.has_method(&"get_source"))
	assert(pole.has_signal(&"powered_changed"))
	if attached_poles.has(pole):
		return
	attached_poles.append(pole)
	if pole.get_powered():
		if powered:
			var result := find_source(pole)
			if result[1] >= separation_from_source:
				return
			source = pole
			generator = result[0]
			separation_from_source = result[1]
		else:
			source = pole
			powered = true
			var result := find_source(pole)
			generator = result[0]
			separation_from_source = result[1]
	pole.powered_changed.connect(on_power_pole_powered_changed.bind(pole))


func on_power_pole_disconnected(pole: Node) -> void:
	assert(not pole == null)
	assert(pole.is_in_group(&"machines"))
	assert(pole.has_signal(&"powered_changed"))
	var index := attached_poles.find(pole)
	if index == -1:
		return
	attached_poles.remove_at(index)
	pole.powered_changed.disconnect(on_power_pole_powered_changed)
	if not powered:
		return
	if pole != source:
		return

	update_source()
	if source == null:
		powered = false

func on_power_pole_powered_changed(value: bool, pole: Node) -> void:
	assert(pole != null)
	if not attached_poles.has(pole):
		return
	assert(powered or value)
	if not powered and value:
		assert(source == null)
		assert(generator == null)
		var result := find_source(pole)
		source = pole
		generator = result[0]
		separation_from_source = result[1]
		powered = true
	elif powered and value:
		assert(source != null)
		var result := find_source(pole)
		if result[1] >= separation_from_source:
			return
		source = pole
		generator = result[0]
		separation_from_source = result[1]
	elif powered and not value and pole == source:
		assert(source != null)
		update_source()
		if source == null:
			powered = false

func on_animation_finished(anim_name: StringName) -> void:
	if anim_name != &"power_up":
		return
	cool_down_timer.start()

func on_cooldown_timer_timeout() -> void:
	assert(powered)
	assert(state == State.IDLE)
	assert(source != null)
	assert(generator != null)
	var tile_origin := world_map.local_to_map(get_global_position())
	var potential_mining_targets := tile_map_detection_area.find_closest_tiles(is_valid_mining_target.bind(tile_origin))
	if potential_mining_targets.size() == 0:
		reset_laser_head()
		cool_down_timer.start()
		return

	target_tile_offset = potential_mining_targets[randi_range(0, potential_mining_targets.size() - 1)]
	if target_tile_offset.x < -target_tile_offset.y:
		laser_head.position.y = -1.0
		const INV_SQRT_2 := 0.70710678
		const UP = Vector2(-INV_SQRT_2, -INV_SQRT_2)
		var dot = UP.dot(Vector2(target_tile_offset).normalized())
		laser_head.scale = Vector2(
			lerpf(1.0, 0.7, dot),
			lerpf(1.0, 0.8, dot)
		)
	else:
		laser_head.position.y = 0.0
		laser_head.scale = Vector2.ONE

	var target_center := world_map.map_to_local(tile_origin + target_tile_offset)

	var quarter_tile_size := Vector2(world_map.tile_set.tile_size) / 4.0
	var target_face_offset: Vector2
	if absf(target_tile_offset.x) < absf(target_tile_offset.y):
		quarter_tile_size = Vector2(quarter_tile_size.x, -quarter_tile_size.y)
		target_face_offset = quarter_tile_size if target_tile_offset.y > 0 else -quarter_tile_size
	else:
		target_face_offset = quarter_tile_size if target_tile_offset.x < 0 else -quarter_tile_size

	var laser_target := world_map.to_global(target_center + target_face_offset + target_offset)
	laser_head.look_at(laser_target)
	laser_beam.points = [to_local(fire_point.get_global_position()), to_local(laser_target)]
	laser_particles.position = to_local(laser_target)

	state = State.MINING

func on_mining_timer_timeout() -> void:
	assert(powered)
	assert(state == State.MINING)
	assert(source != null)
	assert(generator != null)

	var tile_origin := world_map.local_to_map(get_global_position())
	var target_tile := tile_origin + target_tile_offset
	
	generator.consume_fuel(fuel_consumption_rate * mining_timer.wait_time)

	var energy_cost := world_map.get_cell_mining_energy_cost(target_tile)
	var current_damage := world_map.get_cell_damage(target_tile)
	var damage := mining_power * mining_timer.wait_time
	if current_damage + damage >= energy_cost:
		world_map.reset_cell_damage(target_tile)
		MessageBuss.request_set_world_tile.emit(target_tile, MessageBuss.BlockType.NONE, 0)
		state = State.IDLE
		cool_down_timer.start()
	else:
		world_map.set_cell_damage(target_tile, current_damage + damage)

func on_hover_changed(is_hovered: bool) -> void:
	tile_map_detection_area.visible = is_hovered


func on_body_entered_move_towards_area(body: Node2D) -> void:
	if not body.is_in_group(&"pickup"):
		return
	assert(body.has_method(&"set_target"))
	body.set_target(self)
