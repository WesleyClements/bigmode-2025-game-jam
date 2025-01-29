extends RigidBody2D
class_name pickup

const ItemType = MessageBuss.ItemType

@export var item_type: ItemType
@export var amount: int = 1

func get_type() -> ItemType:
	return item_type

func get_amount() -> int:
	return amount
	
func collect():
	queue_free()
