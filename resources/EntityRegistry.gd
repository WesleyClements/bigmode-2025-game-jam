class_name EntityRegistry
extends Resource

const EntityType = MessageBuss.EntityType

@export var power_pole_cost: int = 1
@export var laser_cost: int = 5


func get_entity_cost(entity_cost: EntityType) -> float:
	match entity_cost:
		EntityType.POWER_POLE:
			return power_pole_cost
		EntityType.LASER:
			return laser_cost
		_:
			return 0.0