class_name EntityRegistry
extends Resource

const EntityType = MessageBuss.EntityType
const ItemType = MessageBuss.ItemType

@export var entity_build_costs: Dictionary[EntityType, float] = {
	EntityType.POWER_POLE: 1.0,
	EntityType.LASER: 5.0
}

@export var entity_mining_energy_costs: Dictionary[EntityType, float] = {
	EntityType.POWER_POLE: 0.5,
	EntityType.LASER: 0.5
}

@export var entity_preview_scenes: Dictionary[EntityType, PackedScene] = {}


func get_entity_build_cost(entity_cost: EntityType) -> float:
	assert(entity_build_costs.has(entity_cost), "No build cost for entity type")
	return entity_build_costs.get(entity_cost, 0.0)

func get_entity_mining_energy_cost(entity_cost: EntityType) -> float:
	assert(entity_mining_energy_costs.has(entity_cost), "No mining energy cost for entity type")
	return entity_mining_energy_costs.get(entity_cost, 0.0)

func get_entity_item_drops(entity_type: EntityType) -> Dictionary[StringName, Dictionary]:
	var build_cost := get_entity_build_cost(entity_type)
	return {
		&"IRON": {
			&"min": build_cost,
			&"max": build_cost
		}
	}

func get_entity_preview_scene(entity_type: EntityType) -> PackedScene:
	assert(entity_preview_scenes.has(entity_type), "No preview scene for entity type")
	return entity_preview_scenes.get(entity_type, null)
