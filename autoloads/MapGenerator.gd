extends CppMapGenerator

signal map_generated()

const TileMaterial = {
	&"EMPTY": 0,
	&"STONE": 1,
	&"COAL": 2,
	&"IRON": 3,
	&"OBSIDIAN": 4,
}


# The lower the number, the bigger the features
@export var initial_scale = 0.081
# High number for ore so we get lots of little pockets (big number = small features)
@export var ore_scale = 0.481

# Similar to conway's game of life, but with different parameters
# Populated tiles with fewer neighbours than the death_limit will die
# Empty tiles with more neighbours than the birth_limit will spawn in
# Serves to smooth out the caves after generating them from the height map
@export var simulation_steps = 4
@export var death_limit = 3
@export var birth_limit = 6


var noise := FastNoiseLite.new()

var noise_with_octaves := FastNoiseLite.new()

var width: int
var height: int
var center: Vector2
var maxDstFromCenter: float
var map: Array[int] = []
var temp_map: Array[int] = []

var generating = false

func generate(_width: int, _height: int) -> Array:
	if generating:
		return map
	generating = true

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

	width = _width
	height = _height
	center = Vector2(width / 2.0, height / 2.0)
	maxDstFromCenter = center.length()
	map.resize(width * height)
	temp_map.resize(width * height)

	gen_height_map()
	map = smooth(map, width, height, simulation_steps, death_limit, birth_limit)
	findOpenSpaces()
	addPrefabs()
	placeOre(TileMaterial.COAL)
	placeOre(TileMaterial.IRON)

	generating = false
	map_generated.emit()
	return map

func placeOre(oreType: int):
	for x in range(width):
		for y in range(height):
			var index = getIndex(x, y)
			if map[index] != TileMaterial.STONE:
				continue
			var xNoise = x * ore_scale
			var yNoise = y * ore_scale
			var result = get_noise(xNoise, yNoise, oreType * 99.9)
			if result > 0.75:
				map[index] = oreType

func addPrefabs():
	addHomebase()

func addHomebase():
	for i in range(-12, 13):
		for j in range(-12, 13):
			if abs(i) > 5 && abs(j) > 1:
				continue
			if abs(j) > 5 && abs(i) > 1:
				continue
			var x = int(center.x) + i
			var y = int(center.y) + j
			var index = getIndex(x, y)
			map[index] = TileMaterial.EMPTY

func gen_height_map():
	for x in range(width):
		for y in range(height):
			var index = getIndex(x, y)
			var xNoise = x * initial_scale
			var yNoise = y * initial_scale
			var dstFromCenter = distanceFromCenter(x, y)

			var result = get_noise_with_octaves(xNoise, yNoise, 0.5)

			# Store off values very close to 0.5, as these are likely the center of larger caves
			var threshold = cosInterpolate(dstFromCenter / (maxDstFromCenter * 0.9), 0.033, 0.000)
			if threshold < 0:
				threshold = 0
			# Spawn stone when not within the threshold. Makes tunnels.
			# Threshold decreases farther from center, decreasing the number of tunnels.
			if (result < 0.5 - threshold || result > 0.5 + threshold) && result < 0.67:
				map[index] = TileMaterial.STONE

func findOpenSpaces():
	for y in range(height):
		var y1 = y * width
		for x in range(width):
			var index = x + y1
			if map[index] == TileMaterial.EMPTY:
				var neighbours = countNeighboursFar(x, y, 2)
				if neighbours <= 2:
					map[index] = TileMaterial.OBSIDIAN

func countNeighboursFar(x: int, y: int, dst: int) -> int:
	var count = 0
	for i in range(-dst, dst+1):
		for j in range(-dst, dst+1):
			if i == 0 && j == 0:
				continue
			var neighbourX = x + i
			var neighbourY = y + j
			if neighbourX < 0 || neighbourY < 0 || neighbourX >= width || neighbourY >= height:
				count += 1 # Off the map, assume alive to avoid clearing out the edges of the map
			elif map[getIndex(neighbourX, neighbourY)]:
				count += 1
	return count

func indexToX(index: int) -> int:
	return index % width

@warning_ignore("integer_division")
func indexToY(index: int) -> int:
	return index / width

func getIndex(x: int, y: int) -> int:
	return x + y * width

func distanceFromCenter(x: int, y: int) -> float:
	var distanceVector = center - Vector2(x, y)
	return distanceVector.length()

func angleFromCenter(x: int, y: int) -> float:
	return center.angle_to_point(Vector2(x, y))


func cosInterpolate(t: float, a: float, b: float) -> float:
	var mu = (1 - cos(t * PI)) / 2;
	return a * (1 - mu) + b * mu;

func get_noise(x: float, y: float, z: float) -> float:
	return (noise.get_noise_3d(x, y, z) + 1.0) / 2.0

func get_noise_with_octaves(x: float, y: float, z: float) -> float:
	return (noise_with_octaves.get_noise_3d(x, y, z) + 1.0) / 2.0
