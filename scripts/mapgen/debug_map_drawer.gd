extends Node2D

const TileMaterial = MapGenerator.TileMaterial

const WIDTH = 200
const HEIGHT = 200

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MapGenerator.map_generated.connect(queue_redraw)
	MapGenerator.generate(WIDTH, HEIGHT)

func _draw():
	if MapGenerator.generating:
		draw_string(SystemFont.new(), Vector2(100, 100), "Generating map...")
		return
	for i in range(WIDTH * HEIGHT):
		var x = MapGenerator.indexToX(i)
		var y = MapGenerator.indexToY(i)
		var mat = MapGenerator.map[i]
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

		draw_rect(Rect2(x * 5, y * 5, 5.0, 5.0), color)
	pass
