extends PanelContainer

@export var positions: PackedVector2Array = []

func _ready() -> void:
	if positions.size() == 0:
		return
	position.y = positions[0].y
	position.x = -size.x / 2.0

func on_iron_changed(iron: float) -> void:
	position.y = positions[floor((positions.size() - 1) * iron / 100.0)].y # TODO: no magic numbers
	position.x = -size.x / 2.0
