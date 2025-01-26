extends Node2D

const TileMaterial = MapGenerator.TileMaterial

@export var wallTilemap: TileMapLayer

const WIDTH = 333
const HEIGHT = 333

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MapGenerator.generate(WIDTH, HEIGHT)
	for i in range(WIDTH * HEIGHT):
		# Map gen creates tiles from [0,WIDTH][0,HEIGHT]
		var mapX = MapGenerator.indexToX(i)
		var mapY = MapGenerator.indexToY(i)
		# The world expects the center to be at 0,0, so transpose to [-WIDTH/2,WIDTH/2][-HEIGHT/2,HEIGHT/2]
		var worldX = mapX - int(MapGenerator.center.x) + 1
		var worldY = mapY - int(MapGenerator.center.y) + 1
		var coords = Vector2i(worldX, worldY)
		var mat = MapGenerator.map[i]
		match mat:
			TileMaterial.STONE:
				wallTilemap.set_cell(coords, 0, Vector2i(0,0))
			TileMaterial.COAL:
				wallTilemap.set_cell(coords, 0, Vector2i(1,0))
			TileMaterial.IRON:
				wallTilemap.set_cell(coords, 0, Vector2i(2,0))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
