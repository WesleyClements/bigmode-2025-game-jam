extends Node2D

@export var audio_stream_players: Array[AudioStreamPlayer2D] = []

var _should_play: bool = false
var _audio_stream_index: int = 0

func _ready() -> void:
	for child in get_children():
		if child is AudioStreamPlayer2D:
			audio_stream_players.append(child)

func _physics_process(_delta: float) -> void:
	if _should_play:
		_should_play = false
		audio_stream_players[_audio_stream_index].play()

func play_random_audio_stream() -> void:
	if audio_stream_players.size() == 0:
		return
	_should_play = true
	_audio_stream_index = randi_range(0, audio_stream_players.size() - 1)
