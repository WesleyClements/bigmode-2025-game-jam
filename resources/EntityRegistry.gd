class_name EntityRegistry
extends Resource

const EntityType = MessageBuss.EntityType
const ItemType = MessageBuss.ItemType

@export var power_pole_build_cost: int = 1
@export var power_pole_mining_energy_cost: float = 0.5
@export var power_pole_preview_scene: PackedScene

@export var laser_build_cost: int = 5
@export var laser_mining_energy_cost: float = 0.5
@export var laser_preview_scene: PackedScene


func get_entity_build_cost(entity_cost: EntityType) -> float:
	match entity_cost:
		EntityType.POWER_POLE:
			return power_pole_build_cost
		EntityType.LASER:
			return laser_build_cost
		_:
			assert(false, "Invalid entity type")
	return 0.0

func get_entity_mining_energy_cost(entity_cost: EntityType) -> float:
	match entity_cost:
		EntityType.POWER_POLE:
			return power_pole_mining_energy_cost
		EntityType.LASER:
			return laser_mining_energy_cost
		_:
			assert(false, "Invalid entity type")
	return 0.0

func get_entity_item_drops(entity_type: EntityType) -> Dictionary:
	match entity_type:
		EntityType.POWER_POLE:
			return {
				&"IRON": {
					&"min": power_pole_build_cost,
					&"max": power_pole_build_cost
				}
			}
		EntityType.LASER:
			return {
				&"IRON": {
					&"min": laser_build_cost,
					&"max": laser_build_cost
				}
			}
		_:
			assert(false, "Invalid entity type")
	return {}

func get_entity_preview_scene(entity_type: EntityType) -> PackedScene:
	match entity_type:
		EntityType.POWER_POLE:
			return power_pole_preview_scene
		EntityType.LASER:
			return laser_preview_scene
		_:
			assert(false, "Invalid entity type")
	return null
