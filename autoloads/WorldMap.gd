extends Node2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")

const TileMaterial = MapGenerator.TileMaterial
const TilesetAtlas = WorldTileMapLayer.TilesetAtlas
const BlockCoords = WorldTileMapLayer.BlockCoords
const BlockType = MessageBuss.BlockType

signal map_generated()


@export var width = 333
@export var height = 333
# The lower the number, the bigger the features
@export var initial_scale = 0.081
# High number for ore so we get lots of little pockets (big number = small features)
@export var ore_scale = 0.281

# Similar to conway's game of life, but with different parameters
# Populated tiles with fewer neighbours than the death_limit will die
# Empty tiles with more neighbours than the birth_limit will spawn in
# Serves to smooth out the caves after generating them from the height map
@export var simulation_steps = 4
@export var death_limit = 5
@export var birth_limit = 6

var map_data: Array[int] = []
var generating = false

var _tile_map: WorldTileMapLayer

@onready var a_star_grid_2d := AStarGrid2D.new()

func _ready() -> void:
	a_star_grid_2d.cell_shape = AStarGrid2D.CELL_SHAPE_ISOMETRIC_DOWN
	a_star_grid_2d.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a_star_grid_2d.jumping_enabled = true

	generate()

func generate() -> bool:
	if generating:
		return false
	generating = true
	
	@warning_ignore("redundant_await")
	map_data = await MapGenerator.generate(
		width,
		height,
		initial_scale,
		simulation_steps,
		death_limit,
		birth_limit,
		ore_scale
	)

	generating = false
	map_generated.emit.call_deferred()
	return true

func populate_tile_map(tile_map: WorldTileMapLayer) -> void:
	var world_center := Vector2i(int(width / 2.0) + 1, int(height / 2.0) + 1)
	for y: int in range(height):
		var yi = y * width
		for x: int in range(width):
			var coords = Vector2i(x, y) - world_center
			match map_data[x + yi]:
				TileMaterial.STONE:
					tile_map.set_cell(coords, TilesetAtlas.TERRAIN, BlockCoords[BlockType.STONE])
				TileMaterial.COAL:
					tile_map.set_cell(coords, TilesetAtlas.TERRAIN, BlockCoords[BlockType.COAL_ORE])
				TileMaterial.IRON:
					tile_map.set_cell(coords, TilesetAtlas.TERRAIN, BlockCoords[BlockType.IRON_ORE])
				_:
					MessageBuss.world_tile_changing.emit(coords, BlockType.NONE, 0)

func generate_a_star_grid_2d(tile_map: WorldTileMapLayer) -> void:
	var world_center := Vector2i(int(width / 2.0) + 1, int(height / 2.0) + 1)
	a_star_grid_2d.region = tile_map.get_used_rect()
	a_star_grid_2d.cell_size = tile_map.tile_set.tile_size
	a_star_grid_2d.update()
	for y in range(height):
		for x in range(width):
			var coords = Vector2i(x, y) - world_center
			a_star_grid_2d.set_point_solid(coords, tile_map.get_cell_source_id(coords) != -1)
	_tile_map = tile_map

func get_navigation_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var from_tile := _tile_map.local_to_map(_tile_map.to_local(from))
	var to_tile := _tile_map.local_to_map(_tile_map.to_local(to))
	var path := a_star_grid_2d.get_point_path(from_tile, to_tile, false)
	if path.size() == 0:
		return path
	path[path.size() - 1] = to
	return path
