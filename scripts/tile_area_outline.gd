@tool
class_name TileAreaOutline
extends Line2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")

@export var root_node: Node:
	get:
		return root_node if root_node else owner
@export var tile_radius := 4
@export var fill := false:
	set(value):
		if fill == value:
			return
		fill = value
		queue_redraw()

func _draw():
	if points.size() == 0:
		return
	var poly_points: PackedVector2Array = points
	poly_points.append(points[0])
	if fill:
		var poly_color := default_color
		poly_color.a *= 0.5
		draw_colored_polygon(poly_points, poly_color)
	if Engine.is_editor_hint():
		draw_polyline(poly_points, default_color, width)

func _ready():
	var tile_size := get_tile_size()
	var x := (tile_radius + 0.5) * tile_size.x
	var y := (tile_radius + 0.5) * tile_size.y

	var outline_points: PackedVector2Array = [
		Vector2(0, y),
		Vector2(x, 0),
		Vector2(0, -y),
		Vector2(-x, 0),
	]
	if not Engine.is_editor_hint():
		points = outline_points
	queue_redraw()


func get_tile_size() -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(32, 16) # TODO no magic numbers
	assert(root_node.has_method(&"get_tile_size"))
	return root_node.get_tile_size() # TODO export node that provides tile size
