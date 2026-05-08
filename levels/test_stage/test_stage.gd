# levels/test_stage/test_stage.gd
extends Node2D

@onready var ready_system = $HUDLayer  # ajuste o path se necessário

func _ready() -> void:
	await get_tree().create_timer(0.3).timeout
	if ready_system and ready_system.has_method("play_ready"):
		ready_system.play_ready()
