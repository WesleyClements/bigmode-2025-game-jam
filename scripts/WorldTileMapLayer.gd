extends TileMapLayer

enum ActionType {
	NONE,
	PLACE_BLOCK,
	REMOVE_BLOCK
}

@export var item_registry: ItemRegistry
@export var wall_tileset_atlas_id := 0

var action_taken: bool = false
var scene_coords := {}

func _enter_tree() -> void:
	child_entered_tree.connect(on_child_entered_tree)
	child_exiting_tree.connect(on_child_exiting_tree)

func _ready() -> void:
	MessageBuss.request_grid_cell_clear.connect(on_grid_cell_clear_request)

func _physics_process(_delta: float) -> void:
	var action := ActionType.NONE

	if (Input.is_action_pressed(&"place_block")):
		action = ActionType.PLACE_BLOCK
	elif (Input.is_action_pressed(&"remove_block")):
		action = ActionType.REMOVE_BLOCK
	
	if action == ActionType.NONE:
		action_taken = false
		return
	
	if action_taken:
		return
	
	action_taken = true
	
	var mouse_pos := to_local(get_global_mouse_position())
	var tile: Vector2i = local_to_map(to_local(mouse_pos))
	var offset := mouse_pos - map_to_local(tile)

	var b := tile_set.tile_size.y / 2.0 - 6.0 # TODO no magic numbers
	var is_left := offset.y > b + offset.x / 2.0
	var is_right := offset.y > b - offset.x / 2.0
	if is_left and is_right and get_cell_source_id(tile + Vector2i(2, 2)) != -1:
		tile = tile + Vector2i(2, 2)
	elif is_left and get_cell_source_id(tile + Vector2i(1, 2)) != -1:
		tile = tile + Vector2i(1, 2)
	elif is_right and get_cell_source_id(tile + Vector2i(2, 1)) != -1:
		tile = tile + Vector2i(2, 1)
	elif get_cell_source_id(tile + Vector2i(1, 1)) != -1:
		tile = tile + Vector2i(1, 1)
	else:
		if offset.x > 0.0:
			if get_cell_source_id(tile + Vector2i(1, 0)) != -1:
				tile = tile + Vector2i(1, 0)
		elif get_cell_source_id(tile + Vector2i(0, 1)) != -1:
			tile = tile + Vector2i(0, 1)


	match action:
		ActionType.PLACE_BLOCK:
			set_cell(tile, 1, Vector2(0, 0), 1)
		ActionType.REMOVE_BLOCK:
			MessageBuss.request_grid_cell_clear.emit(tile)
		

func on_grid_cell_clear_request(cell_pos: Vector2i) -> void:
	if get_cell_source_id(cell_pos) == -1:
		return
	
	MessageBuss.grid_cell_clearing.emit(cell_pos)
	var cell_data := get_cell_tile_data(cell_pos)
	if cell_data != null:
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

func get_cell_scene(cell_pos: Vector2i) -> Node2D:
	return scene_coords.get(cell_pos)

func on_child_entered_tree(child: Node) -> void:
	await child.ready
	var coords := local_to_map(to_local(child.global_position))
	scene_coords[coords] = child
	child.set_meta(&"tile_coords", coords)

func on_child_exiting_tree(child: Node) -> void:
	scene_coords.erase(child.get_meta(&"tile_coords"))