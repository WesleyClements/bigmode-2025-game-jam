extends CharacterBody2D

@export var max_speed: float = 35.0
@export var speed_up_time: float = 0.1
@export var slow_down_time: float = 0.1
@export var stop_distance: float = 20
@export var path_weight: float = 0.5

var target: Node2D
var path: PackedVector2Array = []

@onready var visuals: Node2D = $Visuals

func _draw() -> void:
	var prev: Vector2
	for i: int in range(path.size()):
		var point := path[i]
		if i > 0:
			draw_line(to_local(prev), to_local(point), Color.GREEN, 2)
		prev = point
	if path.size() < 2:
		return
	draw_line(to_local(path[0]), to_local(path[1]), Color.BROWN, 3)

func _physics_process(delta: float) -> void:
	if not target:
		return
	var current_pos := global_position
	var target_pos := target.global_position
	if current_pos.distance_to(target_pos) < stop_distance:
		return

	queue_redraw()
	path = WorldMap.get_navigation_path(current_pos, target_pos)
	if path.size() < 2:
		return
	var weighted_dir := ( # Hack to prevent weasel from getting stuck in corners
		path_weight * current_pos.direction_to(path[0]) +
		current_pos.direction_to(path[1])
	).normalized()
	velocity = velocity.move_toward(weighted_dir * max_speed, max_speed * delta / speed_up_time) # TODO maintain general direction as path changes
	if not is_zero_approx(velocity.x):
		visuals.scale.x = signf(velocity.x)
	move_and_slide()


func on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		target = body