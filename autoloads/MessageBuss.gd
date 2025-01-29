extends Node

enum BlockType {
	NONE,
	ENTITY,
	STONE,
	COAL_ORE,
	IRON_ORE,
}

enum MachineType {
	GENERATOR = 2,
	POWER_POLE = 1,
	LASER = 3,
}

enum ItemType {
	COAL,
	IRON,
}

signal item_count_updated(type: ItemType, count: int)

signal request_set_world_tile(tile_pos: Vector2i, block_type: BlockType, block_variant: int)
signal world_tile_changing(tile_pos: Vector2i, block_type: BlockType, block_variant: int)

func _ready() -> void:
	assert(item_count_updated)
	assert(request_set_world_tile)
	assert(world_tile_changing)