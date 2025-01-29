class_name MapGenerator
extends CppMapGenerator

enum TileMaterial {
	EMPTY = 0,
	STONE = 1,
	COAL = 2,
	IRON = 3,
	OBSIDIAN = 4,
}


static var noise := FastNoiseLite.new()

static var noise_with_octaves := FastNoiseLite.new()

static func generate(width: int, height: int, initial_scale := 0.081, simulation_steps := 4, death_limit := 3, birth_limit := 6, ore_scale := 0.481) -> Array[int]:
	noise.noise_type = FastNoiseLite.NoiseType.TYPE_PERLIN
	noise.fractal_type = FastNoiseLite.FractalType.FRACTAL_NONE
	noise.frequency = 1
	noise.seed = randi()

	noise_with_octaves.noise_type = FastNoiseLite.NoiseType.TYPE_PERLIN
	noise_with_octaves.fractal_type = FastNoiseLite.FractalType.FRACTAL_FBM
	noise_with_octaves.fractal_octaves = 8
	noise_with_octaves.fractal_gain = 0.45
	noise_with_octaves.frequency = 1
	noise_with_octaves.seed = randi()

	var center := Vector2(width / 2.0, height / 2.0)
	var map: Array[int] = []
	map.resize(width * height)

	gen_height_map(map, width, height, initial_scale, center)
	map = CppMapGenerator.smooth(map, width, height, simulation_steps, death_limit, birth_limit)
	find_open_spaces(map, width, height)
	add_prefabs(map, width, height, center)
	place_ore(map, width, height, TileMaterial.COAL, ore_scale)
	place_ore(map, width, height, TileMaterial.IRON, ore_scale)

	return map

static func gen_height_map(map: Array[int], width: int, height: int, initial_scale: float, center: Vector2) -> void:
	var max_dist_from_center := center.length()
	for y: int in range(height):
		var yi := y * width
		for x: int in range(width):

			var result := get_noise_with_octaves(x * initial_scale, y * initial_scale, 0.5)

			const MAX_NOISE_VALUE := 0.67
			if result > MAX_NOISE_VALUE:
				continue

			var dist_from_center := (center - Vector2(x, y)).length()

			const MAX_THRESHOLD := 0.033
			# Store off values very close to 0.5, as these are likely the center of larger caves
			var threshold := maxf(
				0.0,
				Tween.interpolate_value(
					MAX_THRESHOLD, #
					-MAX_THRESHOLD,
					dist_from_center / (max_dist_from_center * 0.9), # TODO: no magic numbers
					1.0, # means output will be initial_value + delta_value when elapsed_time is 1.0
					Tween.TransitionType.TRANS_SINE,
					Tween.EaseType.EASE_IN_OUT
				)
			)
			
			const THRESHOLD_OFFSET := 0.5
			# Spawn stone when not within the threshold. Makes tunnels.
			# Threshold decreases farther from center, decreasing the number of tunnels.
			if absf(result - THRESHOLD_OFFSET) < threshold:
				continue
			map[x + yi] = TileMaterial.STONE

static func add_prefabs(map: Array[int], width: int, height: int, center: Vector2) -> void:
	add_homebase(map, width, height, center)

static func add_homebase(map: Array[int], width: int, _height: int, center: Vector2) -> void:
	const STRUCTURE_RADIUS := 12
	var center_int := Vector2i(center)
	for j: int in range(-STRUCTURE_RADIUS, STRUCTURE_RADIUS + 1):
		var y := center_int.y + j
		var yi := y * width
		for i: int in range(-STRUCTURE_RADIUS, STRUCTURE_RADIUS + 1):
			if abs(i) > 5 && abs(j) > 1: # TODO: Magic numbers
				continue
			if abs(j) > 5 && abs(i) > 1: # TODO: Magic numbers
				continue
			var x := center_int.x + i
			map[x + yi] = TileMaterial.EMPTY

static func find_open_spaces(map: Array[int], width: int, height: int) -> void:
	for y: int in range(height):
		var yi := y * width
		for x: int in range(width):
			var index = x + yi
			if map[index] != TileMaterial.EMPTY:
				continue
			var neighbors = CppMapGenerator.count_neighbors(map, width, height, x, y, 2)
			if neighbors > 2:
				continue
			map[index] = TileMaterial.OBSIDIAN

static func place_ore(map: Array[int], width: int, height: int, ore_type: int, ore_scale: float) -> void:
	for y: int in range(height):
		var yi := y * width
		for x: int in range(width):
			var index = x + yi
			if map[index] != TileMaterial.STONE:
				continue
			var result = get_noise(
				x * ore_scale,
				y * ore_scale,
				ore_type * 99.9 # TODO: Magic number
			)
			const MIN_NOISE_VALUE := 0.75
			if result < MIN_NOISE_VALUE:
				continue
			map[index] = ore_type

static func get_noise(x: float, y: float, z: float) -> float:
	return (noise.get_noise_3d(x, y, z) + 1.0) / 2.0

static func get_noise_with_octaves(x: float, y: float, z: float) -> float:
	return (noise_with_octaves.get_noise_3d(x, y, z) + 1.0) / 2.0
