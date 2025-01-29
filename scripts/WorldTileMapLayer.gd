extends TileMapLayer

enum TilesetAtlas {
	TERRAIN = 0,
	ENTITIES = 1
}

const BlockType = MessageBuss.BlockType
const ItemType = MessageBuss.ItemType

const BlockCoords = {
	BlockType.STONE: Vector2i(0, 0),
	BlockType.COAL_ORE: Vector2i(1, 0),
	BlockType.IRON_ORE: Vector2i(2, 0),
}

@export var item_registry: ItemRegistry
@export var tileset_atlas_id: TilesetAtlas = TilesetAtlas.TERRAIN
@export var hover_outline_color: Color = Color(1, 1, 1, 0.5)
@export var hover_outline_width: float = 1.0

var scene_coords := {}
var hovered_tile: Vector2i = Vector2i(-1, -1)

func _enter_tree() -> void:
	child_entered_tree.connect(on_child_entered_tree)
	child_exiting_tree.connect(on_child_exiting_tree)

func _ready() -> void:
	MessageBuss.request_set_world_tile.connect(on_set_world_tile_request)
	MessageBuss.world_tile_changing.connect(on_world_tile_changing)

	await WorldMap.map_generated
	WorldMap.populate_tile_map(self)
	WorldMap.generate_a_star_grid_2d(self)


func _process(_delta: float) -> void:
	var mouse_pos := get_global_mouse_position()
	var tile_pos := mouse_to_map(mouse_pos)
	if tile_pos != hovered_tile:
		hovered_tile = tile_pos
		queue_redraw()

func _draw() -> void:
	var center := map_to_local(hovered_tile)
	var half_tile_size := tile_set.tile_size / 2
	draw_polyline([center + Vector2(0, half_tile_size.y), center + Vector2(half_tile_size.x, 0), center + Vector2(0, -half_tile_size.y), center + Vector2(-half_tile_size.x, 0), center + Vector2(0, half_tile_size.y)], hover_outline_color, hover_outline_width)

func get_cell_scene(cell_pos: Vector2i) -> Node2D:
	return scene_coords.get(cell_pos)

func mouse_to_map(mouse_pos: Vector2) -> Vector2i:
	mouse_pos = to_local(mouse_pos)

	var tile: Vector2i = local_to_map(to_local(mouse_pos))
	var offset := mouse_pos - map_to_local(tile)

	var b := tile_set.tile_size.y / 2.0 - 6.0 # TODO no magic numbers
	var is_left := offset.y > b + offset.x / 2.0
	var is_right := offset.y > b - offset.x / 2.0
	if is_left and is_right and get_cell_source_id(tile + Vector2i(2, 2)) != -1:
		return tile + Vector2i(2, 2)
	if is_left and get_cell_source_id(tile + Vector2i(1, 2)) != -1:
		return tile + Vector2i(1, 2)
	if is_right and get_cell_source_id(tile + Vector2i(2, 1)) != -1:
		return tile + Vector2i(2, 1)
	if get_cell_source_id(tile + Vector2i(1, 1)) != -1:
		return tile + Vector2i(1, 1)
	
	if offset.x > 0.0 and get_cell_source_id(tile + Vector2i(1, 0)) != -1:
		return tile + Vector2i(1, 0)
	if offset.x < 0.0 and get_cell_source_id(tile + Vector2i(0, 1)) != -1:
		return tile + Vector2i(0, 1)
	
	return tile

func update_cell(coords: Vector2i, source_id: int = -1, atlas_coords: Vector2i = Vector2i(-1, -1), alternative_tile: int = 0) -> void:
	if source_id == -1:
		erase_cell(coords)
	else:
		set_cell(coords, source_id, atlas_coords, alternative_tile)
	assert(WorldMap.a_star_grid_2d.is_in_boundsv(coords))
	WorldMap.a_star_grid_2d.set_point_solid(coords, source_id != -1)
	
func on_set_world_tile_request(tile_pos: Vector2i, block_type: BlockType, block_variant: int) -> void:
	match block_type:
		BlockType.NONE:
			if get_cell_source_id(tile_pos) == -1:
				return
			MessageBuss.world_tile_changing.emit(tile_pos, block_type, block_variant)
			update_cell(tile_pos)
		BlockType.ENTITY:
			if get_cell_source_id(tile_pos) == TilesetAtlas.ENTITIES and get_cell_alternative_tile(tile_pos) == block_variant:
				return
			MessageBuss.world_tile_changing.emit(tile_pos, block_type, block_variant)
			update_cell(tile_pos, TilesetAtlas.ENTITIES, Vector2(0, 0), block_variant)
		BlockType.STONE, BlockType.COAL_ORE, BlockType.IRON_ORE:
			if get_cell_source_id(tile_pos) == TilesetAtlas.TERRAIN and get_cell_atlas_coords(tile_pos) == BlockCoords[block_type] and get_cell_alternative_tile(tile_pos) == block_variant:
				return
			MessageBuss.world_tile_changing.emit(tile_pos, block_type, block_variant)
			update_cell(tile_pos, TilesetAtlas.TERRAIN, BlockCoords[block_type], block_variant)
		_:
			assert(false, "Unknown block type")
	

func on_world_tile_changing(tile_pos: Vector2i, block_type: BlockType, _block_variant: int) -> void:
	match block_type:
		BlockType.NONE:
			var cell_data := get_cell_tile_data(tile_pos)
			if cell_data == null:
				return
			var item_drops: Dictionary = cell_data.get_custom_data(&"item_drops")
			if item_drops == null:
				return
			for item_name: StringName in item_drops.keys():
				var drop_config: Dictionary = item_drops[item_name]
				assert(drop_config != null)
				assert(drop_config.min != null)
				assert(drop_config.max != null)
				var item_type: ItemType = ItemType[item_name]
				var drop_amount := randi_range(drop_config.min, drop_config.max)
				var scene_template := item_registry.get_entity_scene(item_type)
				assert(scene_template != null)
				for _i in range(drop_amount):
					var scene: Node2D = scene_template.instantiate()
					add_child(scene)
					scene.global_position = to_global(map_to_local(tile_pos)) + Vector2(randf() - 0.5, randf() - 0.5) * 2.0 * 4.0 # TODO no magic numbers
		BlockType.STONE:
			pass
		BlockType.COAL_ORE:
			pass
		BlockType.IRON_ORE:
			pass
		BlockType.ENTITY:
			pass
		_:
			assert(false, "Unknown block type")

func on_child_entered_tree(child: Node) -> void:
	await child.ready
	var coords := local_to_map(to_local(child.global_position))
	scene_coords[coords] = child
	child.set_meta(&"tile_coords", coords)

func on_child_exiting_tree(child: Node) -> void:
	scene_coords.erase(child.get_meta(&"tile_coords"))