extends Node2D
class_name pickup

const ItemType = MessageBuss.ItemType

@export var item_type: ItemType
@export var amount: int = 1
@export var speed: float = 70.0
@export var close_enough_distance: float = 5.0

var target: Node2D: set = set_target

func _physics_process(delta):
	if target == null:
		return
	global_position = global_position.move_toward(target.global_position, delta * speed)
	if global_position.distance_to(target.global_position) > close_enough_distance:
		return
	target = null

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
		return
	if global_position.distance_to(value.global_position) < global_position.distance_to(target.global_position):
			target = value

func collect():
	queue_free()
