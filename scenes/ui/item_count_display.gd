extends Control

const ItemType = MessageBuss.ItemType

@export var display: Label
@export var displayed_item_type: ItemType = ItemType.COAL

func _ready() -> void:
	var players := get_tree().get_nodes_in_group(&"player")
	assert(players.size() == 1)
	var player := players[0]
	assert(player.has_signal(&"item_count_updated"))
	player.item_count_updated.connect(on_item_count_updated)
	display.text = str(0)
	

func on_item_count_updated(item_type: ItemType, count: int):
	if item_type != displayed_item_type:
		return
	display.text = str(count)
