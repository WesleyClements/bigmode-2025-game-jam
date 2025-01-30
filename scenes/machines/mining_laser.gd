extends StaticBody2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const TileMapDetectionArea = preload("res://scenes/tile_map_detection_area.gd")

enum State {
	IDLE,
	SEARCHING,
	MINING
}

signal power_pole_connected(pole: Node)
signal power_pole_disconnected(pole: Node)

@export var minable_tileset_atlas_ids: PackedInt32Array = [0]
@export var energy_consumption_rate := 1.0
@export var target_offset := Vector2(0, -10)
@export var beam_color := Color(1, 0, 0.953125)
@export var beam_width := 2.0

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
			queue_redraw()
		else:
			await animation_player.animation_finished
			powered = true

var state := State.IDLE:
	set(value):
		if state == value:
			return
		state = value
		if state == State.IDLE:
			cool_down_timer.stop()
			mining_timer.stop()
			consumption_timer.stop()

var mining_target_tile: Vector2i
var laser_target: Vector2

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var world_map: WorldTileMapLayer = get_parent()
@onready var tile_map_detection_area: TileMapDetectionArea = $TileMapDetectionArea
@onready var attachment_point: Marker2D = $AttachmentPoint
@onready var laser_head: Node2D = $Laser/LaserHead
@onready var fire_point: Marker2D = $Laser/LaserHead/FirePoint
@onready var cool_down_timer: Timer = $CoolDownTimer
@onready var mining_timer: Timer = $MiningTimer
@onready var consumption_timer: Timer = $ConsumptionTimer


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

func _physics_process(_delta: float) -> void:
	if not powered:
		return
	match state:
		State.IDLE when cool_down_timer.is_stopped():
			cool_down_timer.start()
			queue_redraw()
		State.SEARCHING when cool_down_timer.is_stopped():
			var tile_origin := world_map.local_to_map(get_global_position())
			var potential_mining_targets := tile_map_detection_area.find_closest_tiles(is_valid_mining_target.bind(tile_origin))
			if potential_mining_targets.size() == 0:
				reset_laser_head()
				cool_down_timer.start()
				return
			mining_target_tile = potential_mining_targets[randi_range(0, potential_mining_targets.size() - 1)]
			if mining_target_tile.x < -mining_target_tile.y:
				laser_head.position.y = -1.0
				const INV_SQRT_2 := 0.70710678
				const UP = Vector2(-INV_SQRT_2, -INV_SQRT_2)
				var dot = UP.dot(Vector2(mining_target_tile).normalized())
				laser_head.scale = Vector2(
					lerpf(1.0, 0.7, dot),
					lerpf(1.0, 0.8, dot)
				)
			else:
				laser_head.position.y = 0.0
				laser_head.scale = Vector2.ONE

			var target_center := world_map.map_to_local(tile_origin + mining_target_tile)

			var quarter_tile_size := Vector2(world_map.tile_set.tile_size) / 4.0
			var target_face_offset: Vector2
			if absf(mining_target_tile.x) < absf(mining_target_tile.y):
				quarter_tile_size = Vector2(quarter_tile_size.x, -quarter_tile_size.y)
				target_face_offset = quarter_tile_size if mining_target_tile.y > 0 else -quarter_tile_size
			else:
				target_face_offset = quarter_tile_size if mining_target_tile.x < 0 else -quarter_tile_size

			laser_target = world_map.to_global(target_center + target_face_offset + target_offset)
			laser_head.look_at(laser_target)
			state = State.MINING
		State.MINING when mining_timer.is_stopped():
			queue_redraw()
			mining_timer.start()
			print("Mining")
			consumption_timer.start()
			

func get_attachment_point() -> Marker2D:
	return attachment_point

func reset_laser_head() -> void:
	laser_head.rotation = 0.0
	laser_head.position.y = 0.0
	laser_head.scale = Vector2.ONE

func is_valid_mining_target(tile_map: WorldTileMapLayer, tile_offset: Vector2i, tile_origin: Vector2i) -> bool:
	# if tile_offset.length() > detection_distance:
	# 	return false
	var tile_pos := tile_origin + tile_offset
	return tile_map.get_cell_source_id(tile_pos) in minable_tileset_atlas_ids

func on_power_pole_connected(pole: Node) -> void:
	assert(not pole == null)
	assert(pole.is_in_group(&"machines"))
	assert(pole.has_method(&"get_powered"))
	assert(pole.has_signal(&"powered_changed"))
	if attached_poles.has(pole):
		return
	attached_poles.append(pole)
	if pole.get_powered():
		powered = true
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
	for attached_pole in attached_poles:
		assert(not attached_pole == null)
		assert(attached_pole.has_method(&"get_powered"))
		if attached_pole.get_powered():
			powered = true
			return
	powered = false

func on_power_pole_powered_changed(value: bool, pole: Node) -> void:
	if not attached_poles.has(pole):
		return
	if value:
		powered = true
		return
	for p in attached_poles:
		if p.get_powered():
			powered = true
			return
	powered = false

func on_cooldown_timer_timeout() -> void:
	assert(powered)
	assert(state == State.IDLE or state == State.SEARCHING)
	state = State.SEARCHING

func on_mining_timer_timeout() -> void:
	assert(powered)
	assert(state == State.MINING)
	var remaining_energy := energy_consumption_rate * fmod(mining_timer.wait_time, consumption_timer.wait_time)
	if not is_zero_approx(remaining_energy):
		MessageBuss.consume_energy.emit(remaining_energy)

	var tile_origin := world_map.local_to_map(get_global_position())
	MessageBuss.request_set_world_tile.emit(tile_origin + mining_target_tile, MessageBuss.BlockType.NONE, 0)

	queue_redraw()
	state = State.IDLE

func on_consumption_timer_timeout() -> void:
	assert(powered)
	assert(state == State.MINING)
	MessageBuss.consume_energy.emit(energy_consumption_rate * consumption_timer.wait_time)
