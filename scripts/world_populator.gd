extends Node2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")
const FloorTileMapLayer = preload("res://scripts/FloorTileMapLayer.gd")


const TileMaterial = MapGenerator.TileMaterial
const TilesetAtlas = WorldTileMapLayer.TilesetAtlas
const BlockCoords = WorldTileMapLayer.BlockCoords
const BlockType = MessageBuss.BlockType

@export var wall_tilemap: WorldTileMapLayer
@export var floor_tilemap: FloorTileMapLayer

const WIDTH = 333
const HEIGHT = 333

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MapGenerator.generate(WIDTH, HEIGHT)
	# The world expects the center to be at 0,0, so transpose to [-WIDTH/2,WIDTH/2][-HEIGHT/2,HEIGHT/2]
	var world_center := Vector2i(int(MapGenerator.center.x) + 1, int(MapGenerator.center.y) + 1)
	for y: int in range(HEIGHT):
		var y_offset = y * WIDTH
		for x: int in range(WIDTH):
			var coords = Vector2i(x, y) - world_center
			var mat = MapGenerator.map[x + y_offset]
			match mat:
				TileMaterial.STONE:
					wall_tilemap.set_cell(coords, TilesetAtlas.TERRAIN, BlockCoords[BlockType.STONE])
				TileMaterial.COAL:
					wall_tilemap.set_cell(coords, TilesetAtlas.TERRAIN, BlockCoords[BlockType.COAL_ORE])
				TileMaterial.IRON:
					wall_tilemap.set_cell(coords, TilesetAtlas.TERRAIN, BlockCoords[BlockType.IRON_ORE])
				_:
					floor_tilemap.add_floor_tile(coords)
	
	wall_tilemap.navigation_grid.region = wall_tilemap.get_used_rect()
	wall_tilemap.navigation_grid.update()
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var coords = Vector2i(x, y) - world_center
			wall_tilemap.navigation_grid.set_point_solid(coords, wall_tilemap.get_cell_source_id(coords) != -1)
