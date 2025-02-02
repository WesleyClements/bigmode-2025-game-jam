extends StaticBody2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const TileMapDetectionArea = preload("res://scenes/tile_map_detection_area.gd")

signal iron_changed(value: float)

signal hover_entered()
signal hover_exited()


@export var target_amount: float = 100.0

var attachments: Dictionary = {}

var iron: float = 0.0:
	set(value):
		assert(value >= 0.0)
		iron = minf(value, target_amount)
		iron_changed.emit(iron)
		if iron == target_amount:
			MessageBuss.you_win.emit()

@onready var world_map: WorldTileMapLayer = get_parent()
@onready var iron_display: Label = $IronDisplay
@onready var button_prompt: Panel = $ButtonPrompt

func _ready() -> void:
	iron_changed.emit(iron)

	hover_entered.connect(on_hover_changed.bind(true))
	hover_exited.connect(on_hover_changed.bind(false))

func on_energy_changed() -> void:
	iron_display.text = "%s / %s" % [ceilf(iron), target_amount]

func on_player_interaction_area(_body: Node, entered: bool) -> void:
	button_prompt.visible = entered

func on_hover_changed(_is_hovered: bool) -> void:
	pass