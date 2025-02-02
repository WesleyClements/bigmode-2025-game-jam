extends Node

const Player = preload("res://scenes/player.gd")
const ThePortal = preload("res://scenes/the_portal.gd")

@export var initial_deposit_amount: float = 1.0
@export var deposit_rate: float = 12.0

var frames_since_interaction := 0
var continuously_depositing := false

@onready var portal: ThePortal = owner
@onready var continuous_interaction_timer: Timer = $ContinuousInteractionTimer

func _physics_process(_delta: float) -> void:
	frames_since_interaction += 1
	if frames_since_interaction > 1:
		continuously_depositing = false

func interact(node: Node, _just_pressed: bool) -> void:
	assert(node is Player)
	frames_since_interaction = 0
	var player := node as Player
	if is_zero_approx(player.iron_count):
		player.iron_count = 0.0
		return
	if _just_pressed:
		var transfer_amount := minf(player.iron_count, initial_deposit_amount)
		player.iron_count -= transfer_amount
		portal.iron += transfer_amount
		print("starting timer")
		continuous_interaction_timer.start()
	elif continuously_depositing:
		var transfer_amount := minf(player.iron_count, deposit_rate * get_physics_process_delta_time())
		player.iron_count -= transfer_amount
		portal.iron += transfer_amount

func on_continuous_interaction_timer_timeout() -> void:
	if frames_since_interaction > 1:
		return
	continuously_depositing = true
