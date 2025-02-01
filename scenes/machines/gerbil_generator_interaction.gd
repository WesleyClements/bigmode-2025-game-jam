extends Node

const Player = preload("res://scenes/player.gd")
const GerbilGenerator = preload("res://scenes/machines/gerbil_generator.gd")

@export var deposit_rate: float = 12.0

@onready var generator: GerbilGenerator = owner

func interact(node: Node, _just_pressed: bool) -> void:
	assert(node is Player)
	var player := node as Player
	if is_zero_approx(player.coal_count):
		player.coal_count = 0.0
		return
	var transfer_amount := minf(player.coal_count, deposit_rate * get_physics_process_delta_time())
	player.coal_count -= transfer_amount
	generator.fuel += transfer_amount
