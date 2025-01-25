extends CharacterBody2D

@export var max_speed: float = 70.0
@export var speed_up_time: float = 0.1
@export var slow_down_time: float = 0.1

func _physics_process(delta: float) -> void:

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_up", &"move_down")
	).normalized()
	if not direction.is_zero_approx():
		if velocity.length() < max_speed:
			velocity = velocity.move_toward(direction * max_speed, max_speed * delta / speed_up_time)
		else:
			velocity = direction * max_speed
	else:
		velocity = velocity.move_toward(Vector2(), max_speed * delta / slow_down_time)

	move_and_slide()
