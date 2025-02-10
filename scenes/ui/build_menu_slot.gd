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
		if enable_animation_player != null:
			enable_animation_player.play(&"enable" if enabled else &"disable")
@export var selected: bool = false:
	set(value):
		if selected == value:
			return
		selected = value
		if selection_animation_player != null:
			selection_animation_player.play(&"select" if selected else &"deselect")

@onready var icon: TextureRect = %Icon
@onready var hot_key_display: Label = %HotKeyName
@onready var enable_animation_player: AnimationPlayer = $EnableAnimationPlayer
@onready var selection_animation_player: AnimationPlayer = $SelectionAnimationPlayer

func _ready() -> void:
	icon.texture = texture
	hot_key_display.text = hot_key_name

	if Engine.is_editor_hint():
		return
	enabled = false
	var players := get_tree().get_nodes_in_group(&"player")
	assert(players.size() == 1)
	var player := players[0]
	assert(player.has_signal(&"item_count_updated"))
	assert(player.has_signal(&"set_selected_entity_type"))
	player.item_count_updated.connect(on_item_count_updated)
	player.set_selected_entity_type.connect(on_set_selected_entity_type)

func on_item_count_updated(type: ItemType, count: int) -> void:
	if type != ItemType.IRON:
		return
	var cost := entity_registry.get_entity_build_cost(entity_type)
	enabled = count >= cost

@warning_ignore("shadowed_variable")
func on_set_selected_entity_type(entity_type: EntityType, successful: bool) -> void:
	if successful:
		selected = entity_type == self.entity_type
	elif entity_type == self.entity_type:
		selection_animation_player.play(&"insufficient")