extends Node2D

enum TileMaterial {
	EMPTY,
	STONE,      
	COAL,
	IRON,
} 

const WIDTH = 200
const HEIGHT = 200
var map_gen = MapGenerator.new(WIDTH, HEIGHT)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	map_gen.generate()

func _draw():
	for i in range(WIDTH * HEIGHT):
		var x = map_gen.indexToX(i)
		var y = map_gen.indexToY(i)
		var mat = map_gen.map[i]
		var color: Color
		match mat:
			TileMaterial.STONE:
				color = Color.DARK_GRAY
			TileMaterial.COAL:
				color = Color.BLACK
			TileMaterial.IRON:
				color = Color.GOLD
			_:
				color = Color.WHITE

		draw_rect(Rect2(x*5, y*5, 5.0, 5.0), color)
	pass
