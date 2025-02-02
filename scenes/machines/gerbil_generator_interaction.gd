extends Node

const Player = preload("res://scenes/player.gd")
const GerbilGenerator = preload("res://scenes/machines/gerbil_generator.gd")

@export var initial_deposit_amount: float = 1.0
@export var deposit_rate: float = 6.0
@export var deposit_rate_acceleration: float = 3.0
@export var deposit_rate_jerk: float = 1.0

var frames_since_interaction := 0
var continuously_depositing := false
var continuous_deposit_rate: float
var continuous_deposit_rate_acceleration: float

@onready var generator: GerbilGenerator = owner
@onready var continuous_interaction_timer: Timer = $ContinuousInteractionTimer

func _physics_process(_delta: float) -> void:
	frames_since_interaction += 1
	if frames_since_interaction > 1:
		continuously_depositing = false
		continuous_deposit_rate = deposit_rate
		continuous_deposit_rate_acceleration = deposit_rate_acceleration

func interact(node: Node, _just_pressed: bool) -> void:
	assert(node is Player)
	frames_since_interaction = 0
	var player := node as Player
	if is_zero_approx(player.coal_count):
		player.coal_count = 0.0
		return
	if _just_pressed:
		var transfer_amount := minf(player.coal_count, initial_deposit_amount)
		player.coal_count -= transfer_amount
		generator.fuel += transfer_amount
		continuous_interaction_timer.start()
	elif continuously_depositing:
		var delta := get_physics_process_delta_time()
		var transfer_amount := minf(player.coal_count, continuous_deposit_rate * delta)
		continuous_deposit_rate += continuous_deposit_rate_acceleration * delta
		continuous_deposit_rate_acceleration += deposit_rate_jerk * delta
		player.coal_count -= transfer_amount
		generator.fuel += transfer_amount

func on_continuous_interaction_timer_timeout() -> void:
	if frames_since_interaction > 1:
		return
	continuously_depositing = true
