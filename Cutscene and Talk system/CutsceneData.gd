# talksystem/CutsceneData.gd
class_name CutsceneData
extends Resource

@export var steps: Array[CutsceneStep] = []

# O que acontece ao apertar Enter — pula todos os steps e executa isso
# Deixar vazio = sem skip (ex: conversa com Dr.Light não tem skip)
@export var can_skip: bool = true
@export var skip_to_scene: String = ""   # se preenchido, troca de cena ao pular
## Se true, a cutscene é pulada sozinha quando já foi vista nesta partida
## (ex: intro de boss ao tentar a luta de novo). Funciona como o skip por Enter,
## mas automático. O registro é zerado quando uma fase começa (start_stage).
@export var skip_if_seen: bool = false
# Callback interno — preenchido por código, não no editor
var on_skip: Callable
