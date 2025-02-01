extends Node

enum BlockType {
	NONE,
	STONE,
	COAL_ORE,
	IRON_ORE,
}

enum EntityType {
	NONE = 0,
	GENERATOR = 2,
	POWER_POLE = 1,
	LASER = 3,
}

enum ItemType {
	COAL,
	IRON,
}

@warning_ignore("unused_signal")
signal item_count_updated(type: ItemType, count: int)

@warning_ignore("unused_signal")
signal request_set_world_tile(tile_pos: Vector2i, block_type: BlockType, block_variant: int)
@warning_ignore("unused_signal")
signal world_tile_changing(tile_pos: Vector2i, block_type: BlockType, block_variant: int)

@warning_ignore("unused_signal")
signal request_spawn_entity(tile_pos: Vector2i, entity_type: EntityType)
@warning_ignore("unused_signal")
signal entity_spawning(tile_pos: Vector2i, entity_type: EntityType)

@warning_ignore("unused_signal")
signal set_selected_entity_type(entity_type: EntityType)

@warning_ignore("unused_signal")
signal build_mode_entered()

@warning_ignore("unused_signal")
signal build_mode_exited()