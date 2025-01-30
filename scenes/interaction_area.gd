extends Area2D

signal player_entered(node: Node)
signal player_exited(node: Node)

@export var interaction: Node


func get_interaction() -> Node:
	return interaction

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	print("Player exited")
	player_entered.emit(body)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	print("Player exited")
	player_exited.emit(body)
