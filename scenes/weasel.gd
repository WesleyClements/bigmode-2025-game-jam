extends CharacterBody2D

@export var max_speed: float = 35.0
@export var speed_up_time: float = 0.1
@export var slow_down_time: float = 0.1

var target: Node2D
var path: PackedVector2Array = []

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

func _physics_process(_delta: float) -> void:
	if not target:
		return
	var current_pos := global_position
	var target_pos := target.global_position
	if current_pos.distance_to(target_pos) < 8.0: # TODO no magic numbers
		return

	queue_redraw()
	path = WorldMap.get_navigation_path(current_pos, target_pos)
	if path.size() < 2:
		return

	velocity = current_pos.direction_to(path[1]) * max_speed
	move_and_slide()


func on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		target = body