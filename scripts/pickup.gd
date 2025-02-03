extends Node2D
class_name pickup

const ItemType = MessageBuss.ItemType

@export var item_type: ItemType
@export var amount: int = 1
@export var speed: float = 70.0

var target: Vector2 = Vector2.ZERO

func _process(delta):
	if target != Vector2.ZERO:
		global_position = global_position.move_toward(target, delta * speed)
		if global_position.distance_to(target) < 5.0:
			target = Vector2.ZERO

func get_type() -> ItemType:
	return item_type

func get_amount() -> int:
	return amount

func set_target(_target: Vector2):
	if target != Vector2.ZERO:
		return
	target = _target

func collect():
	queue_free()
