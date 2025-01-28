extends Control

var coal_collected := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$coalcount.text = str(coal_collected)
	MessageBuss.item_collected.connect(on_item_collected)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_item_collected(itemtype: MessageBuss.ItemType, amount: int):
	match itemtype:
		MessageBuss.ItemType.COAL:
			coal_collected = coal_collected + amount
			$coalcount.text = str(coal_collected)
