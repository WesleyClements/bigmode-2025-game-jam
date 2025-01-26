extends TileMapLayer

@export var item_registry: ItemRegistry
@export var wall_tileset_atlas_id := 0

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
	var item_drops: Dictionary = cell_data.get_custom_data(&"item_drops")
	if not item_drops == null:
		for item_name: StringName in item_drops.keys():
			var drop_config: Dictionary = item_drops[item_name]
			assert(drop_config != null)
			assert(drop_config.min != null)
			assert(drop_config.max != null)
			var item_type: ItemRegistry.ItemType = ItemRegistry.ItemType[item_name]
			var drop_amount := randi_range(drop_config.min, drop_config.max)
			var scene_template := item_registry.get_entity_scene(item_type)
			if scene_template == null: # TODO assert not null
				continue
			for _i in range(drop_amount):
				var scene: Node2D = scene_template.instantiate()
				add_child(scene)
				scene.global_position = to_global(map_to_local(cell_pos)) + Vector2(randf() - 0.5, randf() - 0.5) * 2.0 * 4.0 # TODO no magic numbers


	erase_cell.call_deferred(cell_pos)