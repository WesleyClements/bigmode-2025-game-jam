extends TileMapLayer


@export var floor_tileset_atlas_id: int = 0
@export var floor_tileset_coords: Vector2i = Vector2i(0, 0)
@export var floor_tileset_alternative_tile_id: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	MessageBuss.grid_cell_clearing.connect(on_grid_cell_clearing)

func add_floor_tile(cell_pos: Vector2i) -> void:
	set_cell(cell_pos, floor_tileset_atlas_id, floor_tileset_coords, floor_tileset_alternative_tile_id)


func on_grid_cell_clearing(cell_pos: Vector2i) -> void:
	add_floor_tile(cell_pos)
