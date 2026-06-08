extends Node
class_name StateMachine

# ── Owner genérico ───────────────────────────────────────────
# Aceita Player, Boss, Enemy ou qualquer Node2D com states filhos.
var _host: Node2D = null

# Atalho tipado — só válido quando _host is Player.
# Todo o código legado dos states do Player continua funcionando
# pois eles acessam `player` e recebem o _host via set().
var player: Node2D:
	get: return _host

var current_state: Node        = null
var current_state_name: String = ""
var previous_state_name: String = ""

var states: Dictionary = {}

# ── Nós opcionais — existem no Player, não no Boss/Enemy ─────
@onready var visual_library: VisualLibrary = _get_visual_library()
@onready var visual_sequence_player: VisualSequenceController = _get_sequence_player()

@export var special_visual_states: Array[String] = ["Intro", "equip"]

# ── Sinal para o Boss flow ───────────────────────────────────
## Emitido pelo state Death do boss quando a animação termina.
## O GameManager escuta isso para avançar o fluxo.
signal death_animation_finished


func _get_visual_library() -> VisualLibrary:
	return get_node_or_null("../VisualLibrary") as VisualLibrary


func _get_sequence_player() -> VisualSequenceController:
	return get_node_or_null("../VisualSequencePlayer") as VisualSequenceController


# ============================================================
# SETUP
# ============================================================

func initialize(p: Node2D) -> void:
	_host = p
	
	_register_states()


func _register_states() -> void:
	states.clear()
	for child in get_children():
		states[child.name] = child
		if child.has_method("set"):
			# "player" mantém compat com todos os states existentes do Player.
			# "owner" é o nome genérico para states de Boss/Enemy.
			child.set("player", _host)
			child.set("owner", _host)
			child.set("state_machine", self)


# ============================================================
# CHANGE STATE
# ============================================================

func change_state(new_state_name: String) -> void:
	if not states.has(new_state_name):
		push_warning("⚠️ Estado não encontrado: " + new_state_name)
		return


	if current_state and current_state.has_method("exit"):
		current_state.exit()

	previous_state_name = current_state_name
	current_state_name  = new_state_name
	current_state       = states[new_state_name]

	if current_state.has_method("enter"):
		current_state.enter()

	# Sequência visual especial (Intro, Equip...) — só se o nó existir.
	if is_special_visual_state(current_state_name) and visual_sequence_player:
		await visual_sequence_player.play(_host, current_state_name)
	elif visual_library:
		visual_library.play_state(current_state_name)


func is_special_visual_state(state_name: String) -> bool:
	return state_name in special_visual_states


# ============================================================
# PROCESS
# ============================================================

func process_state(delta: float) -> void:
	if current_state and current_state.has_method("update"):
		current_state.update(delta)


# ============================================================
# HELPERS
# ============================================================

func get_state_name() -> String:
	return current_state_name


func get_previous_state_name() -> String:
	return previous_state_name


func update_anim() -> void:
	if visual_library:
		visual_library.load_frames("")
