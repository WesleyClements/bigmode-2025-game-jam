class_name ItemRegistry
extends Resource

const ItemType = MessageBuss.ItemType

@export var entity_scenes: Dictionary[ItemType, PackedScene] = {}


func get_entity_scene(item_type: ItemType) -> PackedScene:
	assert(entity_scenes.has(item_type), "No scene for item type")
	return entity_scenes.get(item_type, null)