extends RigidBody2D
class_name pickup

func _ready():
	pass
	
#func _physics_process(delta):
#	move_and_collide(linear_velocity)
	
func collect():
	queue_free()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
