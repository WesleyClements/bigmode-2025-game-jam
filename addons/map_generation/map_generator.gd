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

static var terrain_noise := FastNoiseLite.new()

static var ore_noises : = {
	TileMaterial.COAL: FastNoiseLite.new(),
	TileMaterial.IRON: FastNoiseLite.new(),
}

static func generate(config: MapGenerationConfig) -> Array[int]:
	assert(not is_zero_approx(config.terrain_scale))
	assert(not is_zero_approx(config.ore_scale))
	var terrain_frequency := 1.0
	terrain_noise.noise_type = FastNoiseLite.NoiseType.TYPE_PERLIN
	terrain_noise.fractal_type = FastNoiseLite.FractalType.FRACTAL_FBM
	terrain_noise.fractal_octaves = 8
	terrain_noise.fractal_gain = 0.45
	terrain_noise.frequency = terrain_frequency
	terrain_noise.offset = Vector3(0.0, 0.0, 0.5) # TODO: Magic number

	var ore_frequency := 1.0
	for ore_type in ore_noises.keys():
		var noise : FastNoiseLite = ore_noises.get(ore_type)
		assert(noise != null)
		noise.noise_type = FastNoiseLite.NoiseType.TYPE_PERLIN
		noise.fractal_type = FastNoiseLite.FractalType.FRACTAL_NONE
		noise.frequency = ore_frequency
		noise.offset = Vector3(0.0, 0.0, ore_type * 99.9) # TODO: Magic number

	var center := Vector2(config.width / 2.0, config.height / 2.0)

	var map: Array[int]
	while true:
		map= []
		map.resize(config.width * config.height)

		await gen_height_map(map, config.width, config.height, config.terrain_scale, center)
		map = CppMapGenerator.smooth(
			map,
			config.width,
			config.height,
			config.simulation_steps,
			config.death_limit,
			config.birth_limit
		)
		fill_open_spaces(map, config.width, config.height)
		map = CppMapGenerator.smooth(
			map,
			config.width,
			config.height,
			1,
			config.death_limit,
			config.birth_limit
		)

		# Add predefined structures
		add_homebase(map, config.width, config.height, center)

		# Add ores
		await place_ore(map, config.width, config.height, TileMaterial.COAL, config.ore_scale)
		await place_ore(map, config.width, config.height, TileMaterial.IRON, config.ore_scale)
		
		var empty_tile_total = 0
		const FILL_LIMIT := 400
		empty_tile_total += directional_flood_fill_counter(
			map,
			config.width,
			config.height,
			Vector2i(center),
			Vector2i.UP,
			FILL_LIMIT
		)
		empty_tile_total += directional_flood_fill_counter(
			map,
			config.width,
			config.height,
			Vector2i(center),
			Vector2i.RIGHT,
			FILL_LIMIT
		)
		empty_tile_total += directional_flood_fill_counter(
			map,
			config.width,
			config.height,
			Vector2i(center),
			Vector2i.DOWN,
			FILL_LIMIT
		)
		empty_tile_total += directional_flood_fill_counter(
			map,
			config.width,
			config.height,
			Vector2i(center),
			Vector2i.LEFT,
			FILL_LIMIT
		)
		if empty_tile_total > 1000:
			break
	return map

static func directional_flood_fill_counter(map: Array[int], width: int, height: int, from: Vector2i, direction: Vector2i, limit: int) -> int:	
	var filled: Array[bool] = []
	filled.resize(width * height)
	return directional_flood_fill_counter_recur(map, filled, width, from, direction, limit)

static func directional_flood_fill_counter_recur(map: Array[int], filled: Array[bool], width: int, from: Vector2i, direction: Vector2i, limit: int) -> int:	
	if limit <= 0:
		return 0
	if get_tile(map, width, from):
		return 0
	limit = limit - 1
	var forward = from + direction
	var right = from + perpClockwise(direction)
	var left = from + perpCounterClockwise(direction)
	var count = 1
	if !filled[get_index(forward, width)]:
		filled[get_index(forward, width)] = true
		count = count + directional_flood_fill_counter_recur(map, filled, width, forward, direction, limit)
		limit = limit - count
	if !filled[get_index(right, width)]:
		filled[get_index(right, width)] = true
		count = count + directional_flood_fill_counter_recur(map, filled, width, right, direction, limit)
		limit = limit - count
	if !filled[get_index(left, width)]:
		filled[get_index(left, width)] = true
		count = count + directional_flood_fill_counter_recur(map, filled, width, left, direction, limit)
		limit = limit - count
	return count
	
static func perpClockwise(vector: Vector2i) -> Vector2i:
	return Vector2i(vector.y, -vector.x)

static func perpCounterClockwise(vector: Vector2i) -> Vector2i:
	return Vector2i(-vector.y, vector.x);

static func get_index(from: Vector2i, width: int) -> int:
	return from.x + from.y * width

static func get_tile(map: Array[int], width: int, from: Vector2i) -> int:
	return map[get_index(from, width)]

static func gen_height_map(map: Array[int], width: int, height: int, terrain_scale: float, center: Vector2) -> void:
	terrain_noise.seed = randi()

	var max_dist_from_center := center.length()
	for y: int in range(height):
		var yi := y * width
		for x: int in range(width):

			var noise_value := get_normalized_noise(terrain_noise, x * terrain_scale, y * terrain_scale)

			const MAX_NOISE_VALUE := 0.67
			if noise_value > MAX_NOISE_VALUE:
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
			if absf(noise_value - THRESHOLD_OFFSET) < threshold:
				continue
			map[x + yi] = TileMaterial.STONE

static func add_homebase(map: Array[int], width: int, _height: int, center: Vector2) -> void:
	const STRUCTURE_RADIUS := 1
	const RANGE_UPPER_BOUND := STRUCTURE_RADIUS + 3
	var center_int := Vector2i(center)
	for j: int in range(-STRUCTURE_RADIUS, RANGE_UPPER_BOUND):
		var y := center_int.y + j
		var yi := y * width
		for i: int in range(-STRUCTURE_RADIUS, RANGE_UPPER_BOUND):
			var x := center_int.x + i
			map[x + yi] = TileMaterial.EMPTY

static func fill_open_spaces(map: Array[int], width: int, height: int) -> void:
	var old_map = map.duplicate()
	for y: int in range(height):
		var yi := y * width
		for x: int in range(width):
			var index = x + yi
			if old_map[index] != TileMaterial.EMPTY:
				continue
			var neighbors = CppMapGenerator.count_neighbors(old_map, width, height, x, y, 3)
			if neighbors > 5:
				continue
			map[index] = TileMaterial.STONE

static func place_ore(map: Array[int], width: int, height: int, ore_type: int, ore_scale: float) -> void:
	var ore_noise: FastNoiseLite = ore_noises.get(ore_type)
	assert(ore_noise != null)
	ore_noise.seed = randi()

	for y: int in range(height):
		var yi := y * width
		for x: int in range(width):
			var index = x + yi
			if map[index] != TileMaterial.STONE:
				continue
			var noise_value = get_normalized_noise(
				ore_noise,
				x * ore_scale,
				y * ore_scale,
			)
			const MIN_NOISE_VALUE := 0.66
			if noise_value < MIN_NOISE_VALUE:
				continue
			map[index] = ore_type

static func get_normalized_noise(noise: FastNoiseLite, x: float, y: float, z: float = 0.0) -> float:
	return (noise.get_noise_3d(x, y, z) + 1.0) / 2.0
