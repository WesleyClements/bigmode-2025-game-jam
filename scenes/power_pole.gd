extends Node2D

const PowerPole = preload("res://scenes/power_pole.gd")

static var next_id: int = 0

@export var default_wire_color: Color = Color(0.4, 0.4, 0.4)
@export var powered_wire_color: Color = Color(1, 1, 0)

var id: int = 0
var powered: bool = false

var attached_machines: Dictionary = {}

@onready var attachment_point: Marker2D = $AttachmentPoint

func _ready() -> void:
	id = next_id
	print("Power pole ID: ", id)
	next_id += 1

func _draw() -> void:
	var color = powered_wire_color if powered else default_wire_color
	for machine in attached_machines.keys():
		var connection: MachineConnection = attached_machines.get(machine)
		if not connection.should_draw:
			continue
		print("Drawing connection")
		print(attachment_point.global_position)
		draw_line(to_local(attachment_point.global_position), to_local(connection.attachment_point.global_position), color, 1.5)
	pass

func get_attachment_point() -> Marker2D:
	return attachment_point
	
	
func connect_machine(machine: Node) -> void:
	assert(machine.is_in_group(&"machines"))
	assert(machine.has_method(&"get_attachment_point"))
	var connection := MachineConnection.create(true, machine.get_attachment_point())
	attached_machines[machine] = connection
	if machine is PowerPole:
		if (powered == machine.powered and machine.id < id) or (not powered and machine.powered):
			connection.should_draw = false
			return
	queue_redraw()
	
	# TODO: Connect the machine to the power pole.

func disconnect_machine(machine: Node) -> void:
	var connection: MachineConnection = attached_machines.get(machine)
	if connection == null:
		return
	if machine is PowerPole:
		machine.disconnect_machine(self)
	attached_machines.erase(machine)
	if connection.should_draw:
		queue_redraw()

func on_connection_area_body_entered(body: Node) -> void:
	if body == self:
		return
	if not body.is_in_group(&"machines"):
		return
	connect_machine(body)

class MachineConnection:
	var should_draw: bool
	var attachment_point: Marker2D

	static func create(should_draw: bool, attachment_point: Marker2D) -> MachineConnection:
		var connection = MachineConnection.new()
		connection.should_draw = should_draw
		connection.attachment_point = attachment_point
		return connection