# talksystem/CutsceneSequencer.gd
extends Node

var _cutscene: CutsceneData = null
var _step_index: int = 0
var _running: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TalkManager.dialogue_finished.connect(_on_dialogue_finished)


# =========================
# API PÚBLICA
# =========================
func play(cutscene: CutsceneData, on_skip: Callable = Callable()) -> void:
	_cutscene   = cutscene
	_step_index = 0
	_running    = true

	if on_skip.is_valid():
		_cutscene.on_skip = on_skip

	GameManager.set_input_mode(GameManager.InputMode.MENU)
	InputManager.can_process_player_input = false

	_run_step()


func is_running() -> bool:
	return _running


# =========================
# SKIP (Enter)
# =========================
func _unhandled_input(event: InputEvent) -> void:
	if not _running or not _cutscene:
		return
	if not _cutscene.can_skip:
		return
	if event.is_action_just_pressed("ui_accept"):  # Enter / Start
		_skip()
		get_viewport().set_input_as_handled()


func _skip() -> void:
	_running = false
	TalkManager.skip_all()

	if not _cutscene:
		return

	if not _cutscene.skip_to_scene.is_empty():
		get_tree().change_scene_to_file(_cutscene.skip_to_scene)
		return

	if _cutscene.on_skip.is_valid():
		_cutscene.on_skip.call()
		return

	_finish()


# =========================
# EXECUÇÃO DOS STEPS
# =========================
func _run_step() -> void:
	if not _running:
		return
	if _step_index >= _cutscene.steps.size():
		_finish()
		return

	var step = _cutscene.steps[_step_index]

	match step.get_class():
		"StepDialogue":
			TalkManager.start((step as StepDialogue).dialogue)
			# Continua em _on_dialogue_finished

		"StepWait":
			get_tree().create_timer((step as StepWait).duration).timeout.connect(_advance)

		"StepAnimation":
			_run_step_animation(step as StepAnimation)

		"StepEquipArmor":
			_run_step_equip(step as StepEquipArmor)

		"StepChangeScene":
			get_tree().change_scene_to_file((step as StepChangeScene).scene_path)

		_:
			_advance()


func _run_step_animation(step: StepAnimation) -> void:
	var targets = get_tree().get_nodes_in_group(step.target_group)
	for target in targets:
		if target is AnimatedSprite2D:
			target.play(step.animation)
			if step.wait_to_finish:
				target.animation_finished.connect(_advance, CONNECT_ONE_SHOT)
				return
		elif target.has_method("play"):
			target.play(step.animation)

	if not step.wait_to_finish:
		_advance()


func _run_step_equip(step: StepEquipArmor) -> void:
	if GameManager.current_player == "X":
		ArmorManager.equip_piece(step.slot)
	_advance()


func _advance() -> void:
	_step_index += 1
	_run_step()


func _on_dialogue_finished() -> void:
	if not _running:
		return
	_advance()


func _finish() -> void:
	_running = false
	GameManager.set_input_mode(GameManager.InputMode.PLAYER)
	InputManager.can_process_player_input = true
	_cutscene = null
