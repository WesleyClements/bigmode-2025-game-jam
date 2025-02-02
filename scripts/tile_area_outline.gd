@tool
class_name TileAreaOutline
extends Line2D

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")

@export var root_node: Node:
	get:
		return root_node if root_node else owner
@export var tile_radius := 4

var _editor_points: PackedVector2Array = []

func _draw():
	if Engine.is_editor_hint():
		draw_polyline(_editor_points, default_color, width)

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
	if Engine.is_editor_hint():
		_editor_points = outline_points
		queue_redraw()
	else:
		points = outline_points


func get_tile_size() -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(32, 16) # TODO no magic numbers
	assert(root_node.get_parent().has_method(&"get_tile_size"))
	return root_node.get_parent().get_tile_size() # TODO export node that provides tile size