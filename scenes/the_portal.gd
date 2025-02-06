extends StaticBody2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const TileMapDetectionArea = preload("res://scenes/tile_map_detection_area.gd")

signal iron_changed(value: float)
signal build_progress_changed(value: float)

signal hover_entered()
signal hover_exited()


@export var target_amount: float = 100.0

var attachments: Dictionary = {}

var iron: float = 0.0:
	set(value):
		assert(value >= 0.0)
		value = minf(value, target_amount)
		if iron == value:
			return
		iron = value
		if is_equal_approx(iron, target_amount):
			iron = target_amount
			build_progress_changed.emit(1.0)
		else:
			build_progress_changed.emit(iron / target_amount)
		iron_changed.emit(iron)


@onready var world_map: WorldTileMapLayer = get_parent()
@onready var iron_display: Label = $IronDisplayPanel/IronDisplay
@onready var button_prompt: Panel = $ButtonPrompt
@onready var portal_sprite: AnimatedSprite2D = $Visuals/Portal

func _ready() -> void:
	portal_sprite.frame = 0
	iron_changed.emit(iron)

	hover_entered.connect(on_hover_changed.bind(true))
	hover_exited.connect(on_hover_changed.bind(false))

func on_iron_changed() -> void:
	iron_display.text = "%s / %s" % [ceilf(iron), target_amount]

func on_player_interaction_area(_body: Node, entered: bool) -> void:
	button_prompt.visible = entered

func on_hover_changed(_is_hovered: bool) -> void:
	pass

func on_build_progress_changed(value: float) -> void:
	var frame_count := portal_sprite.sprite_frames.get_frame_count(&"default")
	if not is_equal_approx(value, 1.0):
		portal_sprite.frame = floorf((frame_count - 1) * iron / target_amount) as int
	else:
		VictoryHandler.you_win.emit()
		portal_sprite.frame = frame_count - 1