# Base_Template_Stage.gd
class_name Base_Template_Stage
extends Node2D



func _ready() -> void:
	# Garante que o save está carregado antes de qualquer coisa
	if not SaveSystem.current_save:
		SaveSystem.create_new_save()

	# Stage filha pode sobrescrever _on_stage_ready para setup específico
	_on_stage_ready()


# Override nas cenas filhas para setup específico do stage
func _on_stage_ready() -> void:
	pass
