# TEMPORÁRIO — só para validar o Batch A. Apague depois dos testes.
# Anexe a um Node qualquer dentro da fase de teste e atribua uma CutsceneData
# no campo "cutscene". Ela toca 1 segundo depois que a fase carrega.
extends Node

@export var cutscene: CutsceneData


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	CutsceneSequencer.play(cutscene)
