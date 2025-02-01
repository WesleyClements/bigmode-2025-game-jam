extends StaticBody2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const TileMapDetectionArea = preload("res://scenes/tile_map_detection_area.gd")

signal powered_changed(powered: bool)
signal energy_changed(energy: float)

@export var wire_template: PackedScene
@export var powered_wire_template: PackedScene

@export var pole_connection_limit: int = 4

@export var generation_rate: float = 1.0
@export var fuel_consumption_rate: float = 1.0

var attachments: Dictionary = {}

var fuel: float = 0.0:
	set(value):
		value = maxf(value, 0.0)
		if is_equal_approx(fuel, value):
			return
		var was_powered := fuel > 0.0
		fuel = 0.0 if is_zero_approx(value) else value
		energy_changed.emit(fuel)

		if not was_powered and fuel > 0.0:
			powered_changed.emit(true)
			update_wires.call_deferred()
		elif was_powered and fuel == 0.0:
			powered_changed.emit(false)
			update_wires.call_deferred()

var _updated_wires: bool = false

@onready var world_map: WorldTileMapLayer = get_parent()
@onready var attachment_point: Marker2D = $AttachmentPoint
@onready var wires: Node2D = $Wires
@onready var tile_map_detection_area: TileMapDetectionArea = $TileMapDetectionArea
@onready var fuel_display: Label = $FuelDisplay
@onready var button_prompt: Panel = $ButtonPrompt

func _enter_tree() -> void:
	search_for_machines.call_deferred()

func _exit_tree() -> void:
	for machine in attachments.keys():
		if machine == null:
			continue
		if machine.has_signal(&"power_pole_disconnected"):
			machine.emit_signal(&"power_pole_disconnected", self)
		if machine.has_method(&"disconnect_machine"):
			machine.disconnect_machine(self)
	attachments.clear()
	
	world_map.child_entered_tree.disconnect(on_world_map_child_update)
	world_map.child_exiting_tree.disconnect(on_world_map_child_update)

func _ready() -> void:
	world_map.child_entered_tree.connect(on_world_map_child_update.bind(true))
	world_map.child_exiting_tree.connect(on_world_map_child_update.bind(false))

func _process(_delta: float) -> void:
	_updated_wires = false

func get_attachment_point() -> Marker2D:
	return attachment_point

func get_powered() -> bool:
	return not is_zero_approx(fuel)

func get_source() -> Node:
	return self

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

func consume_fuel(value: float) -> void:
	fuel -= value
	

func search_for_machines() -> void:
	var machines := []
	for node: Node in tile_map_detection_area.find_scenes():
		if node == self:
			continue
		if not node.is_in_group(&"machines"):
			continue
		machines.append(node)
		if attachments.has(node):
			continue
		connect_machine.call_deferred(node)
	
	for node in attachments.keys():
		if machines.has(node):
			continue
		if node.has_method(&"validate_connection") and node.validate_connection(self):
			continue
		disconnect_machine(node)

func connect_machine(machine: Node) -> bool:
	assert(not machine == null)
	assert(machine.is_in_group(&"machines"))
	assert(machine.has_method(&"get_attachment_point"))
	if attachments.has(machine):
		return true

	attachments[machine] = machine.get_attachment_point()
	if machine.has_signal(&"power_pole_connected"):
		machine.emit_signal(&"power_pole_connected", self)
	if machine.has_method(&"connect_machine"):
		machine.connect_machine(self)
	update_wires.call_deferred()
	return true
	

func disconnect_machine(machine: Node) -> void:
	assert(not machine == null)
	if not attachments.erase(machine):
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

	var template := powered_wire_template if get_powered() else wire_template
	for machine in attachments.keys():
		assert(not machine == null)
		var other_attachment_point: Marker2D = attachments.get(machine)
		var offset := 1.5 * (other_attachment_point.global_position - attachment_point.global_position).normalized()
		var line := template.instantiate()
		wires.add_child(line)
		line.points = [line.to_local(attachment_point.global_position) + offset, line.to_local(other_attachment_point.global_position) - offset]

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

func on_energy_changed() -> void:
	fuel_display.text = "F : " + str(ceilf(fuel))

func on_player_interaction_area(_body: Node, entered: bool) -> void:
	button_prompt.visible = entered