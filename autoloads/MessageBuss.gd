extends Node
enum ItemType {COAL}
signal item_collected(type: ItemType, count: int)

signal request_grid_cell_clear(cell_pos: Vector2i)
signal grid_cell_clearing(cell_pos: Vector2i)

func _ready() -> void:
	assert(item_collected)
	assert(request_grid_cell_clear)
	assert(grid_cell_clearing)