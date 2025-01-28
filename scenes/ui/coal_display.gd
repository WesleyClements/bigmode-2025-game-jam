extends Control

const ItemType = MessageBuss.ItemType

@export var display: Label

func _ready() -> void:
	MessageBuss.item_count_updated.connect(on_item_count_updated)
	display.text = str(0)
	

func on_item_count_updated(item_type: ItemType, count: int):
	if item_type != ItemType.COAL:
		return
	display.text = str(count)
