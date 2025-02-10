extends Node2D
class_name pickup

const ItemType = MessageBuss.ItemType

@export var item_type: ItemType
@export var amount: int = 1
@export var player_suck_speed: float = 70.0
@export var suck_speed: float = 4.0
@export var suck_speed_curve: Curve
@export var suck_speed_curve_max_distance: float = 48.0
@export var suck_distance_variance: float = 32.0
@export var suck_distance_variance_curve: Curve

var target: Node2D: set = set_target
var suck_offset: float

func _physics_process(delta):
	if target == null:
		return
	var current_distance := global_position.distance_to(target.global_position)
	var speed: float
	if target.is_in_group(&"player"):
		speed = player_suck_speed
	else:
		speed = suck_speed * suck_speed_curve.sample(minf(maxf(current_distance + suck_offset, 0.0) / suck_speed_curve_max_distance, 1.0))
	global_position = global_position.move_toward(target.global_position, delta * speed)

func get_type() -> ItemType:
	return item_type

func get_amount() -> int:
	return amount

func set_target(value: Node2D):
	if value == null:
		target = null
		return
	if value.is_in_group(&"player"):
		target = value
		return
	if target == null:
		target = value
	elif global_position.distance_to(value.global_position) < global_position.distance_to(target.global_position):
		target = value
	suck_offset = -suck_distance_variance * suck_distance_variance_curve.sample(randf())

func collect():
	queue_free()
