extends StaticBody2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")

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

var attached_poles := []

var powered: bool = false:
	set(value):
		powered = value
		print("Powered: ", value)
		animation_tree.set("parameters/conditions/powered", value)

var state := State.IDLE
var is_waiting := false
var mining_target: Vector2i

@onready var attachment_point: Marker2D = $AttachmentPoint
@onready var world_map: WorldTileMapLayer = get_parent()
@onready var animation_tree: AnimationTree = $AnimationTree


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

func _physics_process(_delta: float) -> void:
	if not powered:
		return
	match state:
		State.SEARCHING:
			var tile_origin = world_map.local_to_map(get_global_position())
			var potential_mining_targets = []
			for distance in range(1, detection_distance + 1):
				if is_valid_mining_target(tile_origin, Vector2i(0, distance)):
					potential_mining_targets.append(Vector2i(0, distance))
				if is_valid_mining_target(tile_origin, Vector2i(distance, 0)):
					potential_mining_targets.append(Vector2i(distance, 0))
				if is_valid_mining_target(tile_origin, Vector2i(0, -distance)):
					potential_mining_targets.append(Vector2i(0, -distance))
				if is_valid_mining_target(tile_origin, Vector2i(-distance, 0)):
					potential_mining_targets.append(Vector2i(-distance, 0))
				
				if potential_mining_targets.size() > 0:
					break
					
				for offset in range(1, distance):
					if is_valid_mining_target(tile_origin, Vector2i(offset, distance)):
						potential_mining_targets.append(Vector2i(offset, distance))
					if is_valid_mining_target(tile_origin, Vector2i(-offset, distance)):
						potential_mining_targets.append(Vector2i(-offset, distance))
					if is_valid_mining_target(tile_origin, Vector2i(offset, -distance)):
						potential_mining_targets.append(Vector2i(offset, -distance))
					if is_valid_mining_target(tile_origin, Vector2i(-offset, -distance)):
						potential_mining_targets.append(Vector2i(-offset, -distance))
					if is_valid_mining_target(tile_origin, Vector2i(distance, offset)):
						potential_mining_targets.append(Vector2i(distance, offset))
					if is_valid_mining_target(tile_origin, Vector2i(distance, -offset)):
						potential_mining_targets.append(Vector2i(distance, -offset))
					if is_valid_mining_target(tile_origin, Vector2i(-distance, offset)):
						potential_mining_targets.append(Vector2i(-distance, offset))
					if is_valid_mining_target(tile_origin, Vector2i(-distance, -offset)):
						potential_mining_targets.append(Vector2i(-distance, -offset))
					if potential_mining_targets.size() > 0:
						break
				
				if potential_mining_targets.size() > 0:
					break

				if is_valid_mining_target(tile_origin, Vector2i(distance, distance)):
					potential_mining_targets.append(Vector2i(distance, distance))
				if is_valid_mining_target(tile_origin, Vector2i(distance, -distance)):
					potential_mining_targets.append(Vector2i(distance, -distance))
				if is_valid_mining_target(tile_origin, Vector2i(-distance, distance)):
					potential_mining_targets.append(Vector2i(-distance, distance))
				if is_valid_mining_target(tile_origin, Vector2i(-distance, -distance)):
					potential_mining_targets.append(Vector2i(-distance, -distance))
				
				if potential_mining_targets.size() > 0:
					break
			
			if potential_mining_targets.size() == 0:
				return
			mining_target = potential_mining_targets[randi_range(0, potential_mining_targets.size() - 1)]
			state = State.MINING
		State.MINING:
			if is_waiting:
				return
			is_waiting = true
			print("Mining target: ", mining_target)
			await get_tree().create_timer(mining_time).timeout
			if not powered:
				state = State.IDLE
				is_waiting = false
				return
			var tile_origin = world_map.local_to_map(get_global_position())
			MessageBuss.request_grid_cell_clear.emit(tile_origin + mining_target)
			state = State.IDLE
			is_waiting = false
		State.IDLE:
			if is_waiting:
				return
			is_waiting = true
			await get_tree().create_timer(cool_down_time).timeout
			state = State.SEARCHING
			is_waiting = false

func get_attachment_point() -> Marker2D:
	return attachment_point

func is_valid_mining_target(tile_origin: Vector2i, tile_offset: Vector2i) -> bool:
	if tile_offset.length() > detection_distance:
		return false
	var tile_pos := tile_origin + tile_offset
	return world_map.get_cell_source_id(tile_pos) in minable_tileset_atlas_ids

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