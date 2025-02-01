@tool
class_name TileAreaOutline
extends Line2D

static func _append_points(array: PackedVector2Array, start_point: Vector2, offset: Vector2, point_count: int, index_offset := 0) -> void:
	for i: int in range(point_count):
		array[index_offset + i] = start_point + i * offset

const WorldTileMapLayer = preload("res://scripts/WorldTileMapLayer.gd")

@export var root_node: Node2D:
	get:
		return root_node if root_node else owner
@export var tile_radius := 4

@onready var world_map: WorldTileMapLayer = null if Engine.is_editor_hint() else root_node.get_parent()

func _ready():
	if Engine.is_editor_hint() and self != owner:
		return
	var points_per_side := tile_radius * 2 + 1
	var tile_size := get_tile_size()
	var segment_size := tile_size / 2.0
	var x := (tile_radius + 0.5) * tile_size.x
	var y := (tile_radius + 0.5) * tile_size.y

	var outline_points: PackedVector2Array = []
	
	outline_points.resize(points_per_side * 4)
	_append_points(
		outline_points,
		Vector2(0, y),
		Vector2(segment_size.x, -segment_size.y),
		points_per_side
	)
	_append_points(
		outline_points,
		Vector2(x, 0),
		Vector2(-segment_size.x, -segment_size.y),
		points_per_side,
		points_per_side
	)
	_append_points(
		outline_points,
		Vector2(0, -y),
		Vector2(-segment_size.x, segment_size.y),
		points_per_side,
		points_per_side * 2
	)
	_append_points(
		outline_points,
		Vector2(-x, 0),
		Vector2(segment_size.x, segment_size.y),
		points_per_side,
		points_per_side * 3
	)
	points = outline_points


func get_tile_size() -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(32, 16) # TODO no magic numbers
	return world_map.tile_set.tile_size