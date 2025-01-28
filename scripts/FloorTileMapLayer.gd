extends TileMapLayer


@export var floor_tileset_atlas_id: int = 0
@export var floor_tileset_coords: Vector2i = Vector2i(0, 0)
@export var floor_tileset_alternative_tile_id: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	MessageBuss.world_tile_changing.connect(on_world_tile_changing)

func add_floor_tile(cell_pos: Vector2i) -> void:
	set_cell(cell_pos, floor_tileset_atlas_id, floor_tileset_coords, floor_tileset_alternative_tile_id)


func on_world_tile_changing(tile_pos: Vector2i, block_type: MessageBuss.BlockType, _block_variant: int) -> void:
	if block_type > MessageBuss.BlockType.ENTITY:
		return
	add_floor_tile(tile_pos)
