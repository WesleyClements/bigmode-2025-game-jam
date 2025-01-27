extends StaticBody2D

const PowerPole = preload("res://scenes/power_pole.gd")
const GerbilGenerator = preload("res://scenes/gerbil_generator.gd")

static var next_id: int = 1

enum ConnectionType {
	GENERATOR,
	POLE,
	MACHINE
}

signal powered_changed(powered: bool)

@export var wire_template: PackedScene
@export var powered_wire_template: PackedScene

@export var pole_connection_limit: int = 4

var id: int
var powered := false

var attached_machines := {}
var attached_poles := {}

var _updated_wires: bool = false

@onready var attachment_point: Marker2D = $AttachmentPoint
@onready var wires: Node2D = $Wires

func _ready() -> void:
	id = next_id
	next_id += 1

func _exit_tree() -> void:
	for machine in attached_machines.keys():
		assert(not machine == null)
		machine.disconnect_machine(self)
	for pole in attached_poles.keys():
		assert(not pole == null)
		pole.disconnect_machine(self)
	attached_machines.clear()
	attached_poles.clear()
	for connection in powered_changed.get_connections():
		powered_changed.disconnect(connection.callable)

func _process(_delta: float) -> void:
	_updated_wires = false

func get_attachment_point() -> Marker2D:
	return attachment_point

func get_powered() -> bool:
	return powered

func get_source() -> Node:
	for pole in attached_poles.keys():
		if attached_poles.get(pole).is_power_source:
			return pole
	return null
	
func connect_machine(machine: Node) -> bool:
	assert(not machine == null)
	assert(machine.is_in_group(&"machines"))
	assert(machine.has_method(&"get_attachment_point"))
	if attached_machines.has(machine) or attached_poles.has(machine):
		return false

	if not machine.has_method(&"connect_machine"):
		attached_machines[machine] = machine.get_attachment_point()
		if machine.has_signal(&"power_pole_connected"):
			machine.emit_signal(&"power_pole_connected", self)
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
	assert(machine.has_method(&"get_powered"))
	var is_power_source: bool = not powered and machine.get_powered()
	attached_poles[machine] = PoleConnection.create(is_power_source, machine.get_attachment_point())

	if is_power_source:
		powered = true
		powered_changed.emit(true)
	
	assert(machine.has_signal(&"powered_changed"))
	machine.powered_changed.connect(on_connected_pole_powered_changed.bind(machine))

	if machine.connect_machine(self):
		return false;

	if powered == machine.get_powered() and machine is PowerPole and id < machine.id:
		update_wires.call_deferred()
	elif powered and not machine.get_powered():
		update_wires.call_deferred()

	return true
	

func disconnect_machine(machine: Node) -> void:
	assert(not machine == null)
	assert(machine.is_in_group(&"machines"))
	if attached_machines.erase(machine):
		if machine.has_signal(&"power_pole_disconnected"):
			machine.emit_signal(&"power_pole_disconnected", self)
		update_wires.call_deferred()
		return
	
	if not attached_poles.erase(machine):
		return

	if machine.has_method(&"disconnect_machine"):
		machine.disconnect_machine(self)
	
	if powered:
		var still_powered := false
		for pole in attached_poles.keys():
			assert(not pole == null)
			assert(pole.has_method(&"get_powered"))
			assert(pole.has_method(&"get_source"))
			if not pole.get_powered():
				continue
			if pole.get_source() == self:
				continue
			var connection: PoleConnection = attached_poles.get(pole)
			connection.is_power_source = true
			still_powered = true
			break
		if not still_powered:
			powered = false
			powered_changed.emit(false)

	update_wires.call_deferred()

func update_wires() -> void:
	if _updated_wires:
		return
	_updated_wires = true

	# TODO update wires instead of recreating them
	for wire in wires.get_children():
		wires.remove_child(wire)
		wire.queue_free()

	for pole: Node in attached_poles.keys():
		assert(not pole == null)
		if pole.get_powered() == powered and (not pole is PowerPole or pole.id < id):
			continue
		var connection: PoleConnection = attached_poles.get(pole)
		var offset := 1.5 * (connection.attachment_point.global_position - attachment_point.global_position).normalized()
		var line := powered_wire_template.instantiate() if powered else wire_template.instantiate()
		wires.add_child(line)
		line.points = [line.to_local(attachment_point.global_position) + offset, line.to_local(connection.attachment_point.global_position) - offset]
	
	for machine: Node in attached_machines.keys():
		assert(not machine == null)
		var other_attachment_point: Marker2D = attached_machines.get(machine)
		var offset := 1.5 * (other_attachment_point.global_position - attachment_point.global_position).normalized()
		var line := powered_wire_template.instantiate() if powered else wire_template.instantiate()
		wires.add_child(line)
		line.points = [line.to_local(attachment_point.global_position) + offset, line.to_local(other_attachment_point.global_position) - offset]
		# TODO sort points from bottom left to top right

func on_connection_area_body_entered(body: Node) -> void:
	if body == self:
		return
	if not body.is_in_group(&"machines"):
		return
	connect_machine(body)

func on_connected_pole_powered_changed(value: bool, updated_pole: Node) -> void:
	var modified_connection = attached_poles.get(updated_pole)
	if modified_connection == null:
		return

	if modified_connection.is_power_source:
		if not value:
			modified_connection.is_power_source = false
			var still_powered := false
			for pole in attached_poles.keys():
				assert(not pole == null)
				assert(pole.has_method(&"get_powered"))
				assert(pole.has_method(&"get_source"))
				if not pole.get_powered():
					continue
				if pole.get_source() == self:
					continue
				var connection: PoleConnection = attached_poles.get(pole)
				connection.is_power_source = true
				still_powered = true
				break
			if not still_powered:
				powered = false
				powered_changed.emit(false)
	elif value and not powered:
		modified_connection.is_power_source = true
		powered = true
		powered_changed.emit(true)

class PoleConnection:
	var is_power_source: bool
	var attachment_point: Marker2D

	static func create(_is_power_source: bool, _attachment_point: Marker2D) -> PoleConnection:
		var connection := PoleConnection.new()
		connection.is_power_source = _is_power_source
		connection.attachment_point = _attachment_point
		return connection
