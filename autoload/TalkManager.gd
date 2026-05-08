# talksystem/TalkManager.gd
extends Node

signal dialogue_finished

const MUGSHOT_PATH   = "res://talksystem/Characters/mugshots/"
const CHAR_SPEED     = 0.03   # segundos por caractere

var _dialogue: DialogueData = null
var _current_line: int = 0
var _is_typing: bool = false
var _full_text: String = ""
var _on_finish: Callable

# Referência à DialogueBox (setada no _ready da DialogueBox)
var _box: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# =========================
# API PÚBLICA
# =========================
func start(dialogue: DialogueData, on_finish: Callable = Callable()) -> void:
	if not _box:
		push_error("TalkManager: DialogueBox não registrada!")
		return

	_dialogue      = dialogue
	_current_line  = 0
	_on_finish     = on_finish
	_is_typing     = false

	GameManager.set_input_mode(GameManager.InputMode.MENU)
	_box.visible = true
	_show_line()


func skip_all() -> void:
	if not _dialogue:
		return
	_end_dialogue()


# Chamado pelo DialogueBox ao pressionar shoot/jump
func on_advance_pressed() -> void:
	if not _dialogue:
		return

	if _is_typing:
		_finish_typing()
	else:
		_next_line()
		
	InputManager.shoot_buffer = 0.0  # ← limpa o buffer
	InputManager.jump_buffer  = 0.0  # ← limpa o buffer


# Registrado pela DialogueBox no _ready
func register_box(box: Control) -> void:
	_box = box


# =========================
# INTERNO
# =========================
func _show_line() -> void:
	if _current_line >= _dialogue.lines.size():
		_end_dialogue()
		return

	var line: DialogueLine = _dialogue.lines[_current_line]
	var speaker_tex = _load_mugshot(line.mugshot)
	var is_player_speaking = line.speaker in ["X", "Zero"]

	# Passa null explicitamente — set_speaker vai esconder o lado sem mugshot
	_box.set_speaker(line.speaker, speaker_tex, is_player_speaking)

	_full_text = line.text
	_is_typing  = true
	_box.start_typewriter(_full_text, CHAR_SPEED)

	if line.auto_advance:
		get_tree().create_timer(line.auto_advance_delay).timeout.connect(
			func():
				if _is_typing:
					_finish_typing()
				else:
					_next_line()
		)
	if _current_line >= _dialogue.lines.size():
		_end_dialogue()
		return


	# Mugshots
	_box.set_speaker(line.speaker, speaker_tex, is_player_speaking)

	# Typewriter
	_full_text = line.text
	_is_typing  = true
	_box.start_typewriter(_full_text, CHAR_SPEED)

	# Auto advance
	if line.auto_advance:
		get_tree().create_timer(line.auto_advance_delay).timeout.connect(
			func():
				if _is_typing:
					_finish_typing()
				else:
					_next_line()
		)


func _finish_typing() -> void:
	_is_typing = false
	_box.complete_text(_full_text)


func _next_line() -> void:
	_current_line += 1
	_show_line()
	InputManager.shoot_buffer = 0.0  # ← limpa o buffer
	InputManager.jump_buffer  = 0.0  # ← limpa o buffer


func _end_dialogue() -> void:
	_dialogue     = null
	_current_line = 0
	_is_typing    = false

	_box.visible = false
	GameManager.set_input_mode(GameManager.InputMode.PLAYER)
	InputManager.can_process_player_input = true
	InputManager.shoot_buffer = 0.0  # ← limpa o buffer
	InputManager.jump_buffer  = 0.0  # ← limpa o buffer

	dialogue_finished.emit()

	if _on_finish.is_valid():
		_on_finish.call()
	_dialogue     = null
	_current_line = 0
	_is_typing    = false

	_box.visible = false
	GameManager.set_input_mode(GameManager.InputMode.PLAYER)
	InputManager.can_process_player_input = true

	dialogue_finished.emit()

	if _on_finish.is_valid():
		_on_finish.call()	
	InputManager.shoot_buffer = 0.0  # ← limpa o buffer
	InputManager.jump_buffer  = 0.0  # ← limpa o buffer

func _load_mugshot(name: String) -> Texture2D:
	if name.is_empty():
		return null
	var path = MUGSHOT_PATH + name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null
