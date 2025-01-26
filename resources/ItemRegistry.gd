class_name ItemRegistry
extends Resource

enum ItemType {
	COAL,
	IRON
}

@export var coal_entity_scene: PackedScene


func get_entity_scene(item_type: ItemType) -> PackedScene:
	match item_type:
		ItemType.COAL:
			return coal_entity_scene
		_:
			return null