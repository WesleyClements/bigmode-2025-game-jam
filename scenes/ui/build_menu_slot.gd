@tool
extends Control

const ItemType = MessageBuss.ItemType
const EntityType = MessageBuss.EntityType

@export var entity_registry: EntityRegistry
@export var entity_type: EntityType
@export var texture: Texture:
	set(value):
		assert(value != null, "Texture must not be null.")
		texture = value
		if icon != null:
			icon.texture = value
@export var hot_key_name: String:
	set(value):
		assert(value != "", "Hot key name must not be empty.")
		hot_key_name = value
		if hot_key_display != null:
			hot_key_display.text = value

@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		if animation_player != null:
			animation_player.play("enable" if value else "disable")
@export var selected: bool = false:
	set(value):
		if selected == value:
			return
		selected = value
		if animation_player != null:
			animation_player.play("select" if value else "deselect")

@onready var icon: TextureRect = $Margin/Icon
@onready var hot_key_display: Label = $HotKeyName
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	MessageBuss.item_count_updated.connect(on_item_count_updated)
	MessageBuss.set_selected_entity_type.connect(on_set_selected_entity_type)
	icon.texture = texture
	hot_key_display.text = hot_key_name
	enabled = false

func on_item_count_updated(type: ItemType, count: int) -> void:
	if type != ItemType.IRON:
		return
	var cost := entity_registry.get_entity_cost(entity_type)
	enabled = count >= cost

@warning_ignore("shadowed_variable")
func on_set_selected_entity_type(entity_type: EntityType) -> void:
	selected = entity_type == self.entity_type