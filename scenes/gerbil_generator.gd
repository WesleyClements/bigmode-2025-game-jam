extends StaticBody2D

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
		assert(not machine == null)
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
		
		print("connecting machine")
		connect_machine(body)

func get_attachment_point() -> Marker2D:
	return attachment_point


func set_powered(_value: bool) -> void:
	pass

func connect_machine(machine: Node) -> bool:
	assert(not machine == null)
	assert(machine.is_in_group(&"machines"))
	assert(machine.has_method(&"get_attachment_point"))
	assert(machine.has_method(&"set_powered"))
	if attached_machines.has(machine):
		return false

	attached_machines[machine] = machine.get_attachment_point()
	machine.set_powered(true)
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
	

func disconnect_machine(machine: Node) -> void:
	assert(not machine == null)
	if not attached_machines.erase(machine):
		return
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
