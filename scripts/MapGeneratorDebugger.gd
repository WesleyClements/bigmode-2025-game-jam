extends Node2D

const TileMaterial = MapGenerator.TileMaterial

var width: int = 333
var height: int = 333
# The lower the number, the bigger the features
var initial_scale = 0.081
# High number for ore so we get lots of little pockets (big number = small features)
var ore_scale = 0.181

# Similar to conway's game of life, but with different parameters
# Populated tiles with fewer neighbours than the death_limit will die
# Empty tiles with more neighbours than the birth_limit will spawn in
# Serves to smooth out the caves after generating them from the height map
var simulation_steps = 5
var death_limit = 5
var birth_limit = 6

var map: Array[int]

func _ready() -> void:
    map = MapGenerator.generate(
		width,
		height,
		initial_scale,
		simulation_steps,
		death_limit,
		birth_limit,
		ore_scale
	)

func _draw():
    for y: int in range(height):
        var yi := y * width
        for x: int in range(width):
            var mat := map[x + yi]
            var color: Color
            match mat:
                TileMaterial.STONE:
                    color = Color.DARK_GRAY
                TileMaterial.COAL:
                    color = Color.BLACK
                TileMaterial.IRON:
                    color = Color.GOLD
                TileMaterial.OBSIDIAN:
                    color = Color.PURPLE
                _:
                    color = Color.WHITE

            draw_rect(Rect2(x * 2, y * 2, 2.0, 2.0), color)