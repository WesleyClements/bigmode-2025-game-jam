extends TileMapLayer

func _physics_process(_delta: float) -> void:
	var tile := local_to_map(to_local(get_global_mouse_position()))
	if (Input.is_action_just_pressed(&"place_block")):
		set_cell(tile, 1, Vector2(0, 0), 1)
	if (Input.is_action_just_pressed(&"remove_block")):
		erase_cell(tile)
