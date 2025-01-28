extends CharacterBody2D

const ItemType = MessageBuss.ItemType

@export var max_speed: float = 70.0
@export var speed_up_time: float = 0.1
@export var slow_down_time: float = 0.1

var coal_count: int = 0
var iron_count: int = 0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var visuals: Node2D = $Visuals


func _on_area_2d_body_entered(body: Node2D):
	print("its working")
	if body.is_in_group(&"pickup"):
		assert(body.has_method(&"collect"))
		assert(body.has_method(&"get_type"))
		assert(body.has_method(&"get_amount"))
		body.collect()
		var type = body.get_type()
		match type:
			ItemType.COAL:
				coal_count += body.get_amount()
				MessageBuss.item_count_updated.emit(ItemType.COAL, coal_count)
			# ItemType.IRON:
			# 	iron_count += body.get_amount()
			# 	MessageBuss.item_count_updated.emit(ItemType.IRON, coal_count)

		
func _physics_process(delta: float) -> void:


	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_up", &"move_down")
	).normalized()
	if not direction.is_zero_approx():
		animation_tree["parameters/conditions/is_idle"] = false
		animation_tree["parameters/conditions/is_moving"] = true
		if velocity.length() < max_speed:
			velocity = velocity.move_toward(direction * max_speed, max_speed * delta / speed_up_time)
		else:
			velocity = direction * max_speed

	elif not velocity.is_zero_approx():
		velocity = velocity.move_toward(Vector2(), max_speed * delta / slow_down_time)
	else:
		animation_tree["parameters/conditions/is_idle"] = true
		animation_tree["parameters/conditions/is_moving"] = false

	if not is_zero_approx(direction.x):
		visuals.scale.x = -1 if direction.x < 0 else 1

	move_and_slide()
