class_name PerlinNoise

# The holy numbers
const permutation = [
        151, 160, 137,  91,  90,  15, 131,  13, 201,  95,  96,  53, 194, 233,   7, 225,
        140,  36, 103,  30,  69, 142,   8,  99,  37, 240,  21,  10,  23, 190,   6, 148,
        247, 120, 234,  75,   0,  26, 197,  62,  94, 252, 219, 203, 117,  35,  11,  32,
        57, 177,  33,  88, 237, 149,  56,  87, 174,  20, 125, 136, 171, 168,  68, 175,
        74, 165,  71, 134, 139,  48,  27, 166,  77, 146, 158, 231,  83, 111, 229, 122,
        60, 211, 133, 230, 220, 105,  92,  41,  55,  46, 245,  40, 244, 102, 143,  54,
        65,  25,  63, 161,   1, 216,  80,  73, 209,  76, 132, 187, 208,  89,  18, 169,
        200, 196, 135, 130, 116, 188, 159,  86, 164, 100, 109, 198, 173, 186,   3,  64,
        52, 217, 226, 250, 124, 123,   5, 202,  38, 147, 118, 126, 255,  82,  85, 212,
        207, 206,  59, 227,  47,  16,  58,  17, 182, 189,  28,  42, 223, 183, 170, 213,
        119, 248, 152,   2,  44, 154, 163,  70, 221, 153, 101, 155, 167,  43, 172,   9,
        129,  22,  39, 253,  19,  98, 108, 110,  79, 113, 224, 232, 178, 185, 112, 104,
        218, 246,  97, 228, 251,  34, 242, 193, 238, 210, 144,  12, 191, 179, 162, 241,
        81,  51, 145, 235, 249,  14, 239, 107,  49, 192, 214,  31, 181, 199, 106, 157,
        184,  84, 204, 176, 115, 121,  50,  45, 127,   4, 150, 254, 138, 236, 205,  93,
        222, 114,  67,  29,  24,  72, 243, 141, 128, 195,  78,  66, 215,  61, 156, 180
]

var p = []
var seedShadowingIsDumb = randi()

func _init():
    p.resize(512)
    for i in range(256):
        p[i] = permutation[i]
        p[256+i] = permutation[i]

func noise(x: float, y: float, z: float) -> float:
    # A reasonable and unflawed way of seeding
    x += seedShadowingIsDumb
    y += seedShadowingIsDumb
    z += seedShadowingIsDumb

    var xi = int(x) & 255
    var yi = int(y) & 255
    var zi = int(z) & 255

    var xx = x - int(x)
    var yy = y - int(y)
    var zz = z - int(z)

    var u = fade(xx)
    var v = fade(yy)
    var w = fade(zz)

    var a  = p[xi] + yi
    var aa = p[a] + zi
    var ab = p[a + 1] + zi
    var b  = p[xi + 1] + yi
    var ba = p[b] + zi
    var bb = p[b + 1] + zi

    var x1 = theCoolerLerp(u, grad(p[aa], xx, yy, zz), grad(p[ba], xx - 1, yy, zz))
    var x2 = theCoolerLerp(u, grad(p[ab], xx, yy - 1, zz), grad(p[bb], xx - 1, yy - 1, zz))
    var y1 = theCoolerLerp(v, x1, x2)

    var x3 = theCoolerLerp(u, grad(p[aa + 1], xx, yy, zz - 1), grad(p[ba + 1], xx - 1, yy, zz - 1))
    var x4 = theCoolerLerp(u, grad(p[ab + 1], xx, yy - 1, zz - 1), grad(p[bb + 1], xx - 1, yy - 1, zz - 1))
    var y2 = theCoolerLerp(v, x3, x4)

    var result = theCoolerLerp(w, y1, y2)

    # Transform [-1,1] to [0,1]
    return (result + 1) / 2

func noiseOctaves(x: float, y: float, z: float, octaves: int) -> float:
    var result = 0
    var amp = 1
    var frequency = 1
    var maxValue = 0
    for i in range(octaves):
        result += amp * noise(x * frequency, y * frequency, z * frequency)
        maxValue += amp
        amp *= 0.45
        frequency *= 2

    return result/maxValue

func fade(t: float) -> float:
    return t * t * t * (t * (t * 6 - 15) + 10)

func theCoolerLerp(t: float, a: float, b: float) -> float:
    return a + t * (b - a)

func grad(hashy: int, x: float, y: float, z: float) -> float:
    # The holy hash
    match hashy & 0xF:
        0x0: return  x + y
        0x1: return -x + y
        0x2: return  x - y
        0x3: return -x - y
        0x4: return  x + z
        0x5: return -x + z
        0x6: return  x - z
        0x7: return -x - z
        0x8: return  y + z
        0x9: return -y + z
        0xA: return  y - z
        0xB: return -y - z
        0xC: return  y + x
        0xD: return -y + z
        0xE: return  y - x
        0xF: return -y - z
        _: return 0
