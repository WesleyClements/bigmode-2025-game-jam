class_name ItemRegistry
extends Resource

const ItemType = MessageBuss.ItemType

@export var coal_entity_scene: PackedScene
@export var iron_entity_scene: PackedScene


func get_entity_scene(item_type: ItemType) -> PackedScene:
	match item_type:
		ItemType.COAL:
			return coal_entity_scene
		ItemType.IRON:
			return iron_entity_scene
		_:
			return null