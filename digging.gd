extends TileMapLayer

func _physics_process(delta):
	var tile : Vector2 = local_to_map(to_local(get_global_mouse_position()))
	if (Input.is_action_just_pressed(&"mb_left")):
		set_cell(tile,0,Vector2(0,0), 0)
	if (Input.is_action_just_pressed(&"mb_right")):
		erase_cell(tile)
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
