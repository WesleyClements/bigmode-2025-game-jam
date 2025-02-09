extends StaticBody2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const TileMapDetectionArea = preload("res://scenes/tile_map_detection_area.gd")

signal powered_changed(powered: bool)

signal fuel_changed(value: float)

signal hover_entered()
signal hover_exited()

@export var wire_template: PackedScene
@export var powered_wire_template: PackedScene

@export var pole_connection_limit: int = 4

@export var max_fuel_consumption: float = 4.0
@export var speed_scale_curve: Curve

var attachments: Dictionary = {}

var fuel: float = 0.0:
	set(value):
		value = maxf(value, 0.0)
		if is_equal_approx(fuel, value):
			return
		var old_fuel := fuel
		fuel = 0.0 if is_zero_approx(value) else value
		fuel_changed.emit(fuel)

		if old_fuel == 0 and fuel > 0.0:
			animation_player.play(&"power_on")
			powered_changed.emit(true)
			update_wires.call_deferred()
		elif old_fuel > 0 and fuel == 0.0:
			animation_player.play(&"power_off")
			fuel_consumption = 0.0
			powered_changed.emit(false)
			update_wires.call_deferred()

var fuel_consumption := 0.0
var _fuel_consumption_accumulator := 0.0

var force_show_outline: bool = false

var _updated_wires: bool = false

@onready var world_map: WorldTileMapLayer = get_parent()
@onready var attachment_point: Marker2D = $AttachmentPoint
@onready var wires: Node2D = $Wires
@onready var tile_map_detection_area: TileMapDetectionArea = $TileMapDetectionArea
@onready var fuel_display: Label = $FuelDisplay
@onready var button_prompt: Panel = $ButtonPrompt
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var wheel_sprite: AnimatedSprite2D = $Visuals/Wheel
@onready var gerbil_sprite: AnimatedSprite2D = $Visuals/Gerbil

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
	fuel_changed.emit(fuel)

	world_map.child_entered_tree.connect(on_world_map_child_update.bind(true))
	world_map.child_exiting_tree.connect(on_world_map_child_update.bind(false))

	hover_entered.connect(on_hover_changed.bind(true))
	hover_exited.connect(on_hover_changed.bind(false))

	MessageBuss.build_mode_entered.connect(on_build_mode_changed.bind(true))
	MessageBuss.build_mode_exited.connect(on_build_mode_changed.bind(false))

func _process(_delta: float) -> void:
	_updated_wires = false

func _physics_process(delta: float) -> void:
	if not get_powered():
		return
	if _fuel_consumption_accumulator > 0.0:
		_fuel_consumption_accumulator /= delta

	if _fuel_consumption_accumulator < fuel_consumption:
		const PERCENTAGE_REDUCTION_PER_SECOND = 0.99
		_fuel_consumption_accumulator = lerpf(
			fuel_consumption,
			_fuel_consumption_accumulator,
			1.0 - pow(1.0 - PERCENTAGE_REDUCTION_PER_SECOND, delta)
		)
		if is_zero_approx(_fuel_consumption_accumulator):
			_fuel_consumption_accumulator = 0.0

	if is_zero_approx(fuel_consumption):
		animation_player.play(&"run" if _fuel_consumption_accumulator > 0.0 else &"power_on")
	elif _fuel_consumption_accumulator > 0.0:
		var gerbil_speed_scale := speed_scale_curve.sample(minf(_fuel_consumption_accumulator / max_fuel_consumption, 1.0))
		wheel_sprite.speed_scale = gerbil_speed_scale
		gerbil_sprite.speed_scale = gerbil_speed_scale

	fuel_consumption = _fuel_consumption_accumulator
	_fuel_consumption_accumulator = 0.0

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
	assert(value >= 0.0)
	_fuel_consumption_accumulator += value
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
	if attachments.has(machine):
		return true

	if machine.has_method(&"get_attachment_point"):
		attachments[machine] = machine.get_attachment_point()
		assert(machine.has_method(&"connect_machine"))
		machine.connect_machine(self)
	else:
		assert(machine.has_signal(&"power_pole_connected"))
		attachments[machine] = null
		machine.emit_signal(&"power_pole_connected", self)
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
		if other_attachment_point == null:
			continue
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

func on_fuel_changed(value: float) -> void:
	fuel_display.text = "%s" % [ceilf(value)]


func on_player_interaction_area(_body: Node, entered: bool) -> void:
	button_prompt.visible = entered

func on_hover_changed(is_hovered: bool) -> void:
	if force_show_outline:
		return
	tile_map_detection_area.visible = is_hovered

func on_build_mode_changed(build_mode: bool) -> void:
	force_show_outline = build_mode
	tile_map_detection_area.visible = build_mode