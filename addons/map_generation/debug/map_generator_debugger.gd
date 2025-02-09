extends Node2D

const TileMaterial = MapGenerator.TileMaterial

var width: int = 333
var height: int = 333
# The lower the number, the bigger the features
var terrain_scale = 0.081
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
	var generation_config = MapGenerationConfig.new()
	generation_config.width = width
	generation_config.height = height
	generation_config.terrain_scale = terrain_scale
	generation_config.ore_scale = ore_scale
	generation_config.simulation_steps = simulation_steps
	generation_config.death_limit = death_limit
	generation_config.birth_limit = birth_limit

	map = await MapGenerator.generate(generation_config)
	queue_redraw()

func _draw():
	if map.size() == 0:
		return
	for y: int in range(height):
		var yi := y * width
		for x: int in range(width):
			draw_rect(
				Rect2(x * 2, y * 2, 2.0, 2.0),
				get_material_color(map[x + yi])
			)

func get_material_color(mat: int) -> Color:
	match mat:
		TileMaterial.STONE:
			return Color.DARK_GRAY
		TileMaterial.COAL:
			return Color.BLACK
		TileMaterial.IRON:
			return Color.GOLD
		TileMaterial.OBSIDIAN:
			return Color.PURPLE
		_:
			return Color.WHITE