extends RigidBody2D
class_name pickup

func _ready():
	pass
	
func collect():
	MessageBuss.item_collected.emit(MessageBuss.ItemType.COAL, 1)
	queue_free()
