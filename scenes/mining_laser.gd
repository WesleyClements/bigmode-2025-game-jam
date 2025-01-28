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

@export var minable_tileset_atlas_ids: Array[int] = [0]
@export var detection_distance := 4.0
@export var mining_time := 0.5
@export var cool_down_time := 0.1
@export var target_offset := Vector2(0, -8)
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
		else:
			await animation_player.animation_finished
			powered = true

var state := State.IDLE
var is_waiting := false
var mining_target_tile: Vector2i
var laser_target: Vector2

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var world_map: WorldTileMapLayer = get_parent()
@onready var tile_map_detection_area: TileMapDetectionArea = $TileMapDetectionArea
@onready var attachment_point: Marker2D = $AttachmentPoint
@onready var laser_head: Node2D = $Laser/LaserHead
@onready var fire_point: Marker2D = $Laser/LaserHead/FirePoint


func _exit_tree() -> void:
	for pole in attached_poles:
		if pole == null:
			continue
		pole.powered_changed.disconnect(on_power_pole_powered_changed)
	attached_poles.clear()
	power_pole_connected.disconnect(on_power_pole_connected)
	power_pole_disconnected.disconnect(on_power_pole_disconnected)

func _draw() -> void:
	if state == State.MINING:
		var source_position := to_local(fire_point.get_global_position())
		var target_position := to_local(laser_target)
		draw_line(source_position, target_position, beam_color, beam_width)


func _ready():
	power_pole_connected.connect(on_power_pole_connected)
	power_pole_disconnected.connect(on_power_pole_disconnected)

func _physics_process(_delta: float) -> void:
	if is_waiting:
		return
	if not powered:
		return
	match state:
		State.SEARCHING:
			var tile_origin := world_map.local_to_map(get_global_position())
			var potential_mining_targets := tile_map_detection_area.find_closest_tiles(is_valid_mining_target.bind(tile_origin))
			if potential_mining_targets.size() == 0:
				reset_laser_head()
				is_waiting = true
				await get_tree().create_timer(cool_down_time).timeout
				is_waiting = false
				return
			mining_target_tile = potential_mining_targets[randi_range(0, potential_mining_targets.size() - 1)]
			if mining_target_tile.x < -mining_target_tile.y:
				laser_head.position.y = -1.0
				const INV_SQRT_2 := 0.70710678
				var dot = Vector2(-INV_SQRT_2, -INV_SQRT_2).normalized().dot(Vector2(mining_target_tile).normalized())
				laser_head.scale = Vector2(
					lerpf(1.0, 0.7, dot),
					lerpf(1.0, 0.8, dot)
				)
			else:
				laser_head.position.y = 0.0
				laser_head.scale = Vector2.ONE
			laser_target = world_map.to_global(
				world_map.map_to_local(tile_origin + mining_target_tile)
			) + target_offset
			laser_head.look_at(laser_target)
			state = State.MINING
		State.MINING:
			queue_redraw()
			is_waiting = true
			await get_tree().create_timer(mining_time).timeout
			if not powered:
				state = State.IDLE
				is_waiting = false
				return
			var tile_origin = world_map.local_to_map(get_global_position())
			MessageBuss.request_grid_cell_clear.emit(tile_origin + mining_target_tile)
			state = State.IDLE
			is_waiting = false
		State.IDLE:
			queue_redraw()
			is_waiting = true
			await get_tree().create_timer(cool_down_time).timeout
			state = State.SEARCHING
			is_waiting = false

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