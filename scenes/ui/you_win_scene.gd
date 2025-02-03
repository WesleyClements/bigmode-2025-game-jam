extends "res://scripts/ui_wrapper.gd"

@onready var time_taken_label: Label = $VBoxContainer/TimeTakenLabel

func _ready() -> void:
	var time_since_start: float = VictoryHandler.get_time_since_start()
	time_taken_label.text = "Time taken %d:%06.3f" % [floorf(time_since_start / 60.0), fmod(time_since_start, 60.0)]
