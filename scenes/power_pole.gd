extends Node2D

const PowerPole = preload("res://scenes/power_pole.gd")

static var next_id: int = 0

enum ConnectionType {
	POLE,
	MACHINE
}

@export var wire_template: PackedScene
@export var pole_connection_limit: int = 4
@export var default_wire_color: Color = Color(0.4, 0.4, 0.4)
@export var powered_wire_color: Color = Color(1, 1, 0)
@export var wire_width: float = 1.5

var id: int = 0
var powered: bool = false:
	set = set_powered

var attached_machines: Dictionary = {}

var _updated_wires: bool = false

@onready var attachment_point: Marker2D = $AttachmentPoint
@onready var wires: Node2D = $Wires

func _ready() -> void:
	id = next_id
	print(id)
	next_id += 1

func _exit_tree() -> void:
	for machine in attached_machines.keys():
		assert(not machine == null)
		machine.disconnect_machine(self)

func _process(_delta: float) -> void:
	_updated_wires = false

func get_attachment_point() -> Marker2D:
	return attachment_point

func set_powered(value: bool) -> void:
	if value == powered:
		return
	# TODO fix power propagation
	powered = value
	update_wires.call_deferred()
	for machine in attached_machines.keys():
		assert(not machine == null)
		assert(machine.has_method(&"set_powered"))
		machine.set_powered(powered)
	
func connect_machine(machine: Node) -> bool:
	assert(not machine == null)
	assert(machine.is_in_group(&"machines"))
	assert(machine.has_method(&"get_attachment_point"))
	if attached_machines.has(machine):
		return false

	if not machine is PowerPole:
		attached_machines[machine] = MachineConnection.create(ConnectionType.MACHINE, machine.get_attachment_point())
		update_wires.call_deferred()
		return true
	
	# TODO fix pole connection limit
	# var pole_count := 0

	# for connection in attached_machines.values():
	# 	if connection.type == ConnectionType.POLE:
	# 		pole_count += 1
	
	# if pole_count > pole_connection_limit:
	# 	var min_distance: float = machine.get_attachment_point().global_position.distance_to(attachment_point.global_position)
	# 	var closest_pole: PowerPole = machine
	# 	for other_machine in attached_machines.keys():
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

	attached_machines[machine] = MachineConnection.create(ConnectionType.POLE, machine.get_attachment_point())

	if machine.connect_machine(self):
		return false;

	if (powered == machine.powered and id < machine.id):
		update_wires.call_deferred()
	elif powered and not machine.powered:
		update_wires.call_deferred()

	return true
	

func disconnect_machine(machine: Node) -> void:
	assert(not machine == null)
	var connection: MachineConnection = attached_machines.get(machine)
	attached_machines.erase(machine)
	if connection == null:
		return
	if machine is PowerPole:
		machine.disconnect_machine(self)
	update_wires.call_deferred()

func update_wires() -> void:
	if _updated_wires:
		return
	_updated_wires = true

	# TODO update wires instead of recreating them
	for wire in wires.get_children():
		wires.remove_child(wire)
		wire.queue_free()

	var color = powered_wire_color if powered else default_wire_color
	for machine in attached_machines.keys():
		assert(not machine == null)
		var connection: MachineConnection = attached_machines.get(machine)
		if not connection.type == ConnectionType.POLE:
			continue
		var pole: PowerPole = machine as PowerPole
		if pole.powered == powered and pole.id < id:
			continue
		var offset := 1.5 * (connection.attachment_point.global_position - attachment_point.global_position).normalized()
		var line := wire_template.instantiate()
		wires.add_child(line)
		line.default_color = color
		line.points = [line.to_local(attachment_point.global_position) + offset, line.to_local(connection.attachment_point.global_position) - offset]

func on_connection_area_body_entered(body: Node) -> void:
	if body == self:
		return
	if not body.is_in_group(&"machines"):
		return
	connect_machine(body)

class MachineConnection:
	var type: ConnectionType
	var attachment_point: Marker2D

	static func create(_type: ConnectionType, _attachment_point: Marker2D) -> MachineConnection:
		var connection := MachineConnection.new()
		connection.type = _type
		connection.attachment_point = _attachment_point
		return connection
