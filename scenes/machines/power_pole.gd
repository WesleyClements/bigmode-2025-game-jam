extends StaticBody2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const TileMapDetectionArea = preload("res://scenes/tile_map_detection_area.gd")
const PowerPole = preload("res://scenes/machines/power_pole.gd")
const GerbilGenerator = preload("res://scenes/machines/gerbil_generator.gd")

static var next_id: int = 1

enum ConnectionType {
	GENERATOR,
	POLE,
	MACHINE
}

signal powered_changed(powered: bool)
signal hover_entered()
signal hover_exited()

@export var wire_template: PackedScene
@export var powered_wire_template: PackedScene

@export var pole_connection_limit: int = 4

var id: int
var powered := false:
	set(value):
		if powered == value:
			return
		powered = value
		powered_changed.emit(value)

var source: Node
var pole_connections := {}
var machine_attachments := {}

var _updated_wires: bool = false
var force_show_outline: bool = false

@onready var world_map: WorldTileMapLayer = get_parent()
@onready var tile_map_detection_area: TileMapDetectionArea = $TileMapDetectionArea
@onready var attachment_point: Marker2D = $AttachmentPoint
@onready var wires: Node2D = $Wires

func _enter_tree() -> void:
	search_for_machines.call_deferred()

func _exit_tree() -> void:
	for machine in machine_attachments.keys():
		if machine == null:
			continue
		if machine.has_signal(&"power_pole_disconnected"):
			machine.emit_signal(&"power_pole_disconnected", self)
	for pole in pole_connections.keys():
		assert(not pole == null)
		pole.disconnect_machine(self)
	machine_attachments.clear()
	pole_connections.clear()
	for connection in powered_changed.get_connections():
		powered_changed.disconnect(connection.callable)
	
	world_map.child_entered_tree.disconnect(on_world_map_child_update)
	world_map.child_exiting_tree.disconnect(on_world_map_child_update)

func _ready() -> void:
	id = next_id
	next_id += 1
	world_map.child_entered_tree.connect(on_world_map_child_update.bind(true))
	world_map.child_exiting_tree.connect(on_world_map_child_update.bind(false))

	hover_entered.connect(on_hover_changed.bind(true))
	hover_exited.connect(on_hover_changed.bind(false))

	MessageBuss.build_mode_entered.connect(on_build_mode_changed.bind(true))
	MessageBuss.build_mode_exited.connect(on_build_mode_changed.bind(false))


func _process(_delta: float) -> void:
	_updated_wires = false

func get_attachment_point() -> Marker2D:
	return attachment_point

func get_powered() -> bool:
	return powered

func get_source() -> Node:
	return source

func validate_connection(node: Node) -> bool:
	if node == null:
		return false
	if node == self:
		return false
	if not node.is_in_group(&"machines"):
		return false
	if not tile_map_detection_area.is_within_detection_distance(node.global_position):
			return false
	return true

func search_for_machines() -> void:
	var machines := []
	for node: Node in tile_map_detection_area.find_scenes():
		if node == self:
			continue
		if not node.is_in_group(&"machines"):
			continue
		machines.append(node)
		if machine_attachments.has(node):
			continue
		if pole_connections.has(node):
			continue
		connect_machine(node)
	
	for node in machine_attachments.keys():
		if machines.has(node):
			continue
		if node.has_method(&"validate_connection") and node.validate_connection(self):
			continue
		disconnect_machine(node)

	for node in pole_connections.keys():
		if machines.has(node):
			continue
		if node.has_method(&"validate_connection") and node.validate_connection(self):
			continue
		disconnect_machine(node)
	
func connect_machine(machine: Node) -> bool:
	assert(not machine == null)
	assert(machine.is_in_group(&"machines"))
	assert(machine.has_method(&"get_attachment_point"))
	if machine_attachments.has(machine) or pole_connections.has(machine):
		return false

	if not machine.has_method(&"connect_machine"):
		machine_attachments[machine] = machine.get_attachment_point()
		if machine.has_signal(&"power_pole_connected"):
			machine.emit_signal(&"power_pole_connected", self)
		update_wires.call_deferred()
		return true
	
	# TODO fix pole connection limit
	# var pole_count := 0

	# for connection in machine_attachments.values():
	# 	if connection.type == ConnectionType.POLE:
	# 		pole_count += 1
	
	# if pole_count > pole_connection_limit:
	# 	var min_distance: float = machine.get_attachment_point().global_position.distance_to(attachment_point.global_position)
	# 	var closest_pole: PowerPole = machine
	# 	for other_machine in machine_attachments.keys():
	# 		assert(not machine == null)
	# 		if not other_machine is PowerPole:
	# 			continue
	# 		var distance: float = machine.get_attachment_point().global_position.distance_to(other_machine.get_attachment_point().global_position)
	# 		if distance < min_distance:
	# 			min_distance = distance
	# 			closest_pole = other_machine as PowerPole
	# 	if closest_pole == machine:
	# 		return false
	# 	disconnect_machine(closest_pole)
	assert(machine.has_method(&"get_powered"))
	pole_connections[machine] = machine.get_attachment_point()

	if not powered and machine.get_powered():
		source = machine
		powered = true
	
	assert(machine.has_signal(&"powered_changed"))
	machine.powered_changed.connect(on_connected_pole_powered_changed.bind(machine))

	if powered == machine.get_powered() and machine is PowerPole and id < machine.id:
		update_wires.call_deferred()
	elif powered and not machine.get_powered():
		update_wires.call_deferred()
	
	if machine.connect_machine(self):
		return false;

	return true
	

func disconnect_machine(machine: Node) -> void:
	assert(not machine == null)
	assert(machine.is_in_group(&"machines"))
	if machine_attachments.erase(machine):
		if machine.has_signal(&"power_pole_disconnected"):
			machine.emit_signal(&"power_pole_disconnected", self)
		update_wires.call_deferred()
		return

	if not pole_connections.erase(machine):
		return

	if machine.has_method(&"disconnect_machine"):
		machine.disconnect_machine(self)
	
	if machine == source:
		update_source()
		if source == null:
			powered = false

	update_wires.call_deferred()

func update_wires() -> void:
	if _updated_wires:
		return
	_updated_wires = true

	# TODO update wires instead of recreating them
	for wire in wires.get_children():
		wires.remove_child(wire)
		wire.queue_free()

	var template := powered_wire_template if powered else wire_template
	const WIRE_OFFSET_LENGTH := 1.5
	for pole: Node in pole_connections.keys():
		assert(not pole == null)
		if pole.get_powered() == powered and (not pole is PowerPole or pole.id < id):
			continue
		var other_attachment_point: Marker2D = pole_connections.get(pole)
		assert(not other_attachment_point == null)
		var wire_direction := (other_attachment_point.global_position - attachment_point.global_position).normalized()
		var offset := WIRE_OFFSET_LENGTH * wire_direction
		var line := template.instantiate()
		wires.add_child(line)
		line.points = [line.to_local(attachment_point.global_position) + offset, line.to_local(other_attachment_point.global_position) - offset]
	
	for other_attachment_point: Marker2D in machine_attachments.values():
		var wire_direction := (other_attachment_point.global_position - attachment_point.global_position).normalized()
		var offset := WIRE_OFFSET_LENGTH * wire_direction
		var line := template.instantiate()
		wires.add_child(line)
		line.points = [line.to_local(attachment_point.global_position) + offset, line.to_local(other_attachment_point.global_position) - offset]
		# TODO sort points from bottom left to top right

func update_source() -> void:
	source = null
	for pole in pole_connections.keys():
		assert(not pole == null)
		assert(pole.has_method(&"get_powered"))
		assert(pole.has_method(&"get_source"))
		if not pole.get_powered():
			continue
		if pole.get_source() == self:
			continue
		source = pole
		break

func on_connected_pole_powered_changed(value: bool, updated_pole: Node) -> void:
	if not pole_connections.has(updated_pole):
		return

	if updated_pole == source and not value:
		assert(powered)
		update_source()
		if source == null:
			powered = false
			update_wires.call_deferred()
	elif value and not powered:
		assert(source == null)
		source = updated_pole
		powered = true
		update_wires.call_deferred()

func on_world_map_child_update(node: Node, is_entering: bool) -> void:
	if is_entering:
		if not validate_connection(node):
			return
		await node.ready
		connect_machine(node)
		return
	if node == self:
		return
	if not node.is_in_group(&"machines"):
		return
	disconnect_machine(node)

func on_hover_changed(is_hovered: bool) -> void:
	if force_show_outline:
		return
	tile_map_detection_area.display_outline = is_hovered

func on_build_mode_changed(build_mode: bool) -> void:
	force_show_outline = build_mode
	tile_map_detection_area.display_outline = build_mode
