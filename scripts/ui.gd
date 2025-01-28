extends Control

var coal_collected := 0

func _ready() -> void:
	$coalcount.text = str(coal_collected)
	MessageBuss.item_collected.connect(on_item_collected)

func on_item_collected(itemtype: MessageBuss.ItemType, amount: int):
	match itemtype:
		MessageBuss.ItemType.COAL:
			coal_collected = coal_collected + amount
			$coalcount.text = str(coal_collected)
