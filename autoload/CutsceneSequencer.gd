# talksystem/CutsceneSequencer.gd
extends Node

var _cutscene: CutsceneData = null
var _step_index: int = 0
var _running: bool = false
## Incrementado a cada _run_step(). Qualquer callback atrasado (sinal de
## animação, de movimento físico, ou o timer chefe) que carregue um token
## antigo é ignorado — assim um Step seguinte nunca é avançado por engano
## por causa de algo que pertencia ao Step anterior.
var _step_token: int = 0
# PATCH — adiciona signal cutscene_finished emitido ao fim de cada cutscene.
# BossFlowManager escuta esse signal para saber quando a intro_cutscene terminou.
signal cutscene_finished(cutscene: CutsceneData)

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

	_step_token += 1
	var step = _cutscene.steps[_step_index]

	# NOTA: get_class() retorna a classe nativa da engine da qual o Resource
	# herda (sempre "Resource" para CutsceneStep e suas subclasses), NUNCA o
	# class_name customizado (StepAnimation, StepDialogue, etc). Por isso o
	# dispatch precisa ser feito com "is", não com get_class()/match por string.
	# Ver README.md para o diagnóstico completo desse bug.
	if step is StepDialogue:
		TalkManager.start((step as StepDialogue).dialogue)
		# Continua em _on_dialogue_finished

	elif step is StepWait:
		get_tree().create_timer((step as StepWait).duration).timeout.connect(_advance)

	elif step is StepAnimation:
		_run_step_animation(step as StepAnimation)

	elif step is StepPhysicalMove:
		_run_step_physical_move(step as StepPhysicalMove)

	elif step is StepEquipArmor:
		_run_step_equip(step as StepEquipArmor)

	elif step is StepChangeScene:
		get_tree().change_scene_to_file((step as StepChangeScene).scene_path)

	else:
		_advance()


func _run_step_animation(step: StepAnimation) -> void:
	var token := _step_token

	# Timer chefe: se step_total_duration > 0, o Step NUNCA dura mais que
	# isso. Com wait_to_finish desmarcado, é ele quem manda o Sequencer
	# avançar (o Step "segura" exatamente esse tempo).
	var has_master_timer := step.step_total_duration > 0.0
	if has_master_timer:
		get_tree().create_timer(step.step_total_duration).timeout.connect(
			_on_step_master_timer.bind(step, token)
		)

	# Com movimento físico embutido: o "fim natural" do Step é o movimento
	# terminar (pousar), NÃO a animação — ela vira só um loop visual,
	# sem relação com a duração real do momento.
	if step.physical_move:
		var mover := _start_physical_move_on_group(step.physical_move.target_group, step.physical_move.move_def)
		_play_animation_on_group(step.target_group, step.animation)
		if step.wait_to_finish:
			if mover:
				mover.physical_move_finished.connect(_advance_if_current.bind(token), CONNECT_ONE_SHOT)
			else:
				push_warning("[CutsceneSequencer] StepAnimation com physical_move, mas nenhum Actor começou a se mover (grupo '%s' vazio/errado, ou PhysicalMoveDef vazio) — avançando sem esperar." % step.physical_move.target_group)
				_advance_if_current(token)
		elif not has_master_timer:
			_advance_if_current(token)
		return

	# Sem movimento embutido: comportamento de sempre, baseado na animação.
	var targets = get_tree().get_nodes_in_group(step.target_group)
	for target in targets:
		if target is AnimatedSprite2D:
			target.play(step.animation)
			if step.wait_to_finish:
				target.animation_finished.connect(_advance_if_current.bind(token), CONNECT_ONE_SHOT)
				return
		elif target.has_method("play"):
			target.play(step.animation)

	if not step.wait_to_finish and not has_master_timer:
		_advance_if_current(token)


## Timer chefe venceu. Só age se este Step ainda for o atual — se ele
## já terminou sozinho (ou o Sequencer já está em outro Step), é um
## callback velho e nada acontece. Para SÓ o movimento físico que ESTE
## Step iniciou; nunca mexe em timers/animações de outros sistemas.
func _on_step_master_timer(step: StepAnimation, token: int) -> void:
	if token != _step_token or not _running:
		return
	if step.physical_move:
		for target in get_tree().get_nodes_in_group(step.physical_move.target_group):
			if target is Actor:
				(target as Actor).stop_physical_move()
	_advance()


## Move um Actor fisicamente durante a cutscene — nunca passa por
## BossAction, chama Actor.start_physical_move() direto. Use isto
## quando quiser SÓ movimento, sem animação nenhuma junto (pra mover
## enquanto uma animação toca, prefira o campo physical_move dentro de
## um StepAnimation — reaproveita este mesmo Step como sub-recurso).
func _run_step_physical_move(step: StepPhysicalMove) -> void:
	var token := _step_token
	var mover := _start_physical_move_on_group(step.target_group, step.move_def)
	if not step.wait_to_finish:
		_advance_if_current(token)
	elif mover:
		mover.physical_move_finished.connect(_advance_if_current.bind(token), CONNECT_ONE_SHOT)
	else:
		push_warning("[CutsceneSequencer] StepPhysicalMove: nenhum Actor começou a se mover (grupo '%s' vazio/errado, ou PhysicalMoveDef vazio) — avançando sem esperar." % step.target_group)
		_advance_if_current(token)


## Inicia a sequência física em todo Actor do grupo. Retorna o PRIMEIRO
## que de fato começou a se mover (é nele que o Sequencer espera), ou
## null se nenhum começou — assim um grupo errado ou um PhysicalMoveDef
## vazio nunca deixa o Step esperando um sinal que jamais vai chegar.
func _start_physical_move_on_group(target_group: String, move_def: PhysicalMoveDef) -> Actor:
	var first_started: Actor = null
	for target in get_tree().get_nodes_in_group(target_group):
		if not (target is Actor):
			continue
		var actor := target as Actor
		actor.start_physical_move(move_def)
		if first_started == null and actor.is_doing_physical_move():
			first_started = actor
	return first_started


func _play_animation_on_group(target_group: String, animation: String) -> void:
	for target in get_tree().get_nodes_in_group(target_group):
		if target.has_method("play"):
			target.play(animation)


## Só avança se o Step que pediu ainda for o atual. Evita que um sinal
## atrasado de um Step anterior avance o Step seguinte por engano.
func _advance_if_current(token: int) -> void:
	if token != _step_token or not _running:
		return
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
	var finished_cutscene := _cutscene   # guarda antes de limpar
	_running = false
	GameManager.set_input_mode(GameManager.InputMode.PLAYER)
	InputManager.can_process_player_input = true
	_cutscene = null
	cutscene_finished.emit(finished_cutscene)
	
# IMPORTANTE: emitir DEPOIS de limpar _cutscene, mas com a referência
# que guardamos antes — assim qualquer listener sabe qual cutscene acabou
# sem depender de _cutscene ainda estar preenchido.
