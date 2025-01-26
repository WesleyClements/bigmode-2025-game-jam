extends TileMapLayer

func _ready() -> void:
	MessageBuss.request_grid_cell_clear.connect(on_grid_cell_clear_request)

func _physics_process(_delta: float) -> void:
	var tile := local_to_map(to_local(get_global_mouse_position()))
	if (Input.is_action_just_pressed(&"place_block")):
		set_cell(tile, 1, Vector2(0, 0), 1)
	if (Input.is_action_just_pressed(&"remove_block")):
		MessageBuss.request_grid_cell_clear.emit(tile)


func on_grid_cell_clear_request(cell_pos: Vector2i) -> void:
	var cell_data := get_cell_tile_data(cell_pos)
	if cell_data == null:
		return
	MessageBuss.grid_cell_clearing.emit(cell_pos)
	erase_cell.call_deferred(cell_pos)