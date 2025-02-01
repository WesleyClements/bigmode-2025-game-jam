class_name EntityRegistry
extends Resource

const EntityType = MessageBuss.EntityType

@export var power_pole_cost: int = 1
@export var power_pole_preview_scene: PackedScene

@export var laser_cost: int = 5
@export var laser_preview_scene: PackedScene


func get_entity_cost(entity_cost: EntityType) -> float:
	match entity_cost:
		EntityType.POWER_POLE:
			return power_pole_cost
		EntityType.LASER:
			return laser_cost
		_:
			assert(false, "Invalid entity type")
	return 0.0

func get_entity_preview_scene(entity_type: EntityType) -> PackedScene:
	match entity_type:
		EntityType.POWER_POLE:
			return power_pole_preview_scene
		EntityType.LASER:
			return laser_preview_scene
		_:
			assert(false, "Invalid entity type")
	return null