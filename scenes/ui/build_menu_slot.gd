@tool
extends Control

@export var texture: Texture:
	set(value):
		assert(value != null, "Texture must not be null.")
		texture = value
		if icon != null:
			icon.texture = value
@export var hot_key_name: String:
	set(value):
		assert(value != "", "Hot key name must not be empty.")
		hot_key_name = value
		if hot_key_display != null:
			hot_key_display.text = value

@onready var icon: TextureRect = $Icon
@onready var hot_key_display: Label = $HotKeyName

func _ready() -> void:
	icon.texture = texture
	hot_key_display.text = hot_key_name