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
@export var beam_color := Color(1, 0, 0.953125)
@export var beam_width := 2.0

var source: Node
var generator: GerbilGenerator
var separation_from_source := MAX_INT
var attached_poles := []

var powered: bool = false:
	set(value):
		if powered == value:
			return
		reset_laser_head()
		cool_down_timer.paused = true
		animation_player.play(&"power_up" if value else &"power_down")
		if not value:
			powered = false
			state = State.IDLE
			queue_redraw()
		else:
			await animation_player.animation_finished
			powered = true
			cool_down_timer.paused = false
			cool_down_timer.start()

var state := State.IDLE:
	set(value):
		if state == value:
			return
		match state:
			State.MINING:
				mining_timer.stop()
			_:
				pass
		state = value
		match state:
			State.IDLE:
				cool_down_timer.start()
			State.MINING:
				mining_timer.start()
				queue_redraw()
			_:
				pass

var target_tile_offset: Vector2i
var laser_target: Vector2

var force_show_outline: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var world_map: WorldTileMapLayer = get_parent()
@onready var tile_map_detection_area: TileMapDetectionArea = $TileMapDetectionArea
@onready var attachment_point: Marker2D = $AttachmentPoint
@onready var laser_head: Node2D = $Laser/LaserHead
@onready var fire_point: Marker2D = $Laser/LaserHead/FirePoint
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

func _draw() -> void:
	if not powered:
		return
	if not state == State.MINING:
		return
	var source_position := to_local(fire_point.get_global_position())
	var target_position := to_local(laser_target)
	draw_line(source_position, target_position, beam_color, beam_width)


func _ready():
	power_pole_connected.connect(on_power_pole_connected)
	power_pole_disconnected.connect(on_power_pole_disconnected)

	hover_entered.connect(on_hover_changed.bind(true))
	hover_exited.connect(on_hover_changed.bind(false))

	MessageBuss.build_mode_entered.connect(on_build_mode_changed.bind(true))
	MessageBuss.build_mode_exited.connect(on_build_mode_changed.bind(false))
			

func get_attachment_point() -> Marker2D:
	return attachment_point

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
	while node != null and node != node.get_source():
		node = node.get_source()
		separation += 1
	assert(node == null or node is GerbilGenerator)
	return [node, separation]

func update_source() -> void:
	source = null
	generator = null
	separation_from_source = MAX_INT

	for attached_pole in attached_poles:
		if not attached_pole.get_powered():
			continue
		var result := find_source(attached_pole)
		if result[1] > separation_from_source:
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
	pole.powered_changed.connect(on_power_pole_powered_changed.bind(pole))
	if not pole.get_powered():
		return
	if source != null:
		var result := find_source(pole)
		if result[1] > separation_from_source:
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


func on_power_pole_disconnected(pole: Node) -> void:
	assert(not pole == null)
	assert(pole.is_in_group(&"machines"))
	assert(pole.has_signal(&"powered_changed"))
	var index := attached_poles.find(pole)
	if index == -1:
		return
	attached_poles.remove_at(index)
	pole.powered_changed.disconnect(on_power_pole_powered_changed)
	if source == null:
		return
	if pole != source:
		return

	update_source()
	if source == null:
		powered = false

func on_power_pole_powered_changed(value: bool, pole: Node) -> void:
	if not attached_poles.has(pole):
		return
	assert(powered or value)
	if source == null and value:
		assert(generator == null)
		var result := find_source(pole)
		source = pole
		generator = result[0]
		separation_from_source = result[1]
		powered = true
	elif source != null and value:
		var result := find_source(pole)
		if result[1] > separation_from_source:
			return
		source = pole
		generator = result[0]
		separation_from_source = result[1]
	elif source != null and not value and pole == source:
		update_source()
		if source == null:
			powered = false

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

	laser_target = world_map.to_global(target_center + target_face_offset + target_offset)
	laser_head.look_at(laser_target)

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
		queue_redraw()
		state = State.IDLE
	else:
		world_map.set_cell_damage(target_tile, current_damage + damage)

func on_hover_changed(is_hovered: bool) -> void:
	if force_show_outline:
		return
	tile_map_detection_area.visible = is_hovered

func on_build_mode_changed(build_mode: bool) -> void:
	force_show_outline = build_mode
	tile_map_detection_area.visible = build_mode
