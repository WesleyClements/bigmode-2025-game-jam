extends Node

signal time_since_start_changed(time: float)

@export var you_win_scene: PackedScene
@export var scene_trans_delay: = 3.0

var time_since_start: float = 0.0:
	set(value):
		time_since_start = value
		time_since_start_changed.emit(time_since_start)

var counting_time: bool = true


func _ready():
	MessageBuss.you_win.connect(on_you_win)

func _physics_process(delta: float):
	if counting_time:
		time_since_start += delta

func get_time_since_start() -> float:
	return time_since_start


func on_you_win() -> void:
	if not counting_time:
		return
	counting_time = false
	await get_tree().create_timer(scene_trans_delay).timeout
	get_tree().change_scene_to_packed(you_win_scene)
