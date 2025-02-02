extends Control


@onready var buttons: Array[Button] = [%Button1, %Button2, %Button3]

func _ready():
	for button: Button in buttons:
		button.pressed.connect(on_button_pressed)


func on_button_pressed() -> void:
	visible = false
	VictoryHandler.start_game.emit()
	queue_free()
