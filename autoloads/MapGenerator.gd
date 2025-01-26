extends Node

signal map_generated()

enum TileMaterial {
    EMPTY,
    STONE,
    COAL,
    IRON,
}


# The lower the number, the bigger the features
@export var initial_scale = 0.081
# High number for ore so we get lots of little pockets (big number = small features)
@export var ore_scale = 0.281

# Similar to conway's game of life, but with different parameters
# Populated tiles with fewer neighbours than the death_limit will die
# Empty tiles with more neighbours than the birth_limit will spawn in
# Serves to smooth out the caves after generating them from the height map
@export var simulation_steps = 6
@export var death_limit = 3
@export var birth_limit = 6

var perlin = PerlinNoise.new()

var width: int
var height: int
var center: Vector2
var maxDstFromCenter: float
var map = []

var generating = false

func generate(_width: int, _height: int) -> Array:
    if generating:
        return map
    generating = true

    width = _width
    height = _height
    center = Vector2(width / 2.0, height / 2.0)
    maxDstFromCenter = center.length()
    map.resize(width * height)
    
    await get_tree().physics_frame

    await gen_height_map()
    await smooth()
    await addPrefabs()
    await placeOre(TileMaterial.COAL)
    await placeOre(TileMaterial.IRON)

    generating = false
    map_generated.emit()
    return map

func placeOre(oreType: int):
    for x in range(width):
        for y in range(height):
            var index = getIndex(x, y)
            if map[index] != TileMaterial.STONE:
                continue
            var xNoise = x * 0.281
            var yNoise = y * 0.281
            var result = perlin.noise(xNoise, yNoise, oreType * 99.9)
            if result > 0.75:
                map[index] = oreType
        await get_tree().physics_frame

func addPrefabs():
    addHomebase()

func addHomebase():
    for i in range(-5, 6):
        for j in range(-5, 6):
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

            var result = perlin.noiseOctaves(xNoise, yNoise, 0.5, 8)

            var threshold = cosInterpolate(dstFromCenter / (maxDstFromCenter * 0.9), 0.035, 0.000)
            if threshold < 0:
                threshold = 0
            # Spawn stone when not within the threshold. Makes tunnels.
            # Threshold decreases farther from center, decreasing the number of tunnels.
            if result < 0.5 - threshold || result > 0.5 + threshold:
                map[index] = TileMaterial.STONE
        await get_tree().physics_frame

func smooth():
    for step in range(simulation_steps):
        await smoothStep()
        

func smoothStep() -> Array:
    var newMap = []
    newMap.resize(width * height)
    for x in range(width):
        for y in range(height):
            var index = getIndex(x, y)
            var neighbours = countNeighbours(x, y)
            if map[index]:
                # Lonely cells kill themselves
                if neighbours < death_limit:
                    newMap[index] = TileMaterial.EMPTY
                else:
                    newMap[index] = TileMaterial.STONE
            else:
                # Dead cells revive when surrounded
                if neighbours > birth_limit:
                    newMap[index] = TileMaterial.STONE
                else:
                    newMap[index] = TileMaterial.EMPTY
        await get_tree().physics_frame
    map = newMap
    return map
            

func countNeighbours(x: int, y: int) -> int:
    var count = 0
    for i in range(-1, 2):
        for j in range(-1, 2):
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
