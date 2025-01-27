extends StaticBody2D

signal powered_changed(powered: bool)

@export var pole_connection_limit: int = 4
@export var powered_wire_template: PackedScene

var attached_machines: Dictionary = {}

var _updated_wires: bool = false

@onready var attachment_point: Marker2D = $AttachmentPoint
@onready var wires: Node2D = $Wires
@onready var connection_area: ShapeCast2D = $ConnectionArea

func _ready() -> void:
	connection_area.add_exception(self)

func _exit_tree() -> void:
	for machine in attached_machines.keys():
		if machine == null:
			continue
		if machine.has_method(&"disconnect_machine"):
			machine.disconnect_machine(self)
	attached_machines.clear()

func _process(_delta: float) -> void:
	_updated_wires = false

func _physics_process(_delta: float) -> void:
	connection_area.force_shapecast_update()
	for i in range(connection_area.get_collision_count()):
		var body = connection_area.get_collider(i)
		if not body.is_in_group(&"machines"):
			continue
		if attached_machines.has(body):
			continue
		connect_machine(body)

func get_attachment_point() -> Marker2D:
	return attachment_point

func get_powered() -> bool:
	return true

func get_source() -> Node:
	return self

func connect_machine(machine: Node) -> bool:
	assert(not machine == null)
	assert(machine.is_in_group(&"machines"))
	assert(machine.has_method(&"get_attachment_point"))
	if attached_machines.has(machine):
		return true

	attached_machines[machine] = machine.get_attachment_point()
	if machine.has_signal(&"power_pole_connected"):
		machine.emit_signal(&"power_pole_connected", self)
	if machine.has_method(&"connect_machine"):
		machine.connect_machine(self)
	update_wires.call_deferred()
	return true
	

func disconnect_machine(machine: Node) -> void:
	assert(not machine == null)
	if not attached_machines.erase(machine):
		return
	if machine.has_signal(&"power_pole_disconnected"):
		machine.emit_signal(&"power_pole_disconnected", self)
	if machine.has_method(&"disconnect_machine"):
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

	for machine in attached_machines.keys():
		assert(not machine == null)
		var other_attachment_point: Marker2D = attached_machines.get(machine)
		var offset := 1.5 * (other_attachment_point.global_position - attachment_point.global_position).normalized()
		var line := powered_wire_template.instantiate()
		wires.add_child(line)
		line.points = [line.to_local(attachment_point.global_position) + offset, line.to_local(other_attachment_point.global_position) - offset]

func on_connection_area_body_entered(body: Node) -> void:
	if body == self:
		return
	if not body.is_in_group(&"machines"):
		return
	connect_machine(body)
