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
## Muda a cada step terminado: cancela os sons em loop/burst do step anterior.
var _effects_token: int = 0
## Cutscenes já vistas (terminadas ou puladas) nesta partida: chave → true.
## Usado por CutsceneData.skip_if_seen. Em memória de propósito: vale por partida,
## não por save (ver reset_seen()).
var _seen: Dictionary = {}
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
	_effects_token += 1   # invalida efeitos pendentes de uma cutscene anterior

	if on_skip.is_valid():
		_cutscene.on_skip = on_skip

	GameManager.set_input_mode(GameManager.InputMode.MENU)
	InputManager.can_process_player_input = false

	# Já vista nesta partida e marcada pelo designer: pula na hora, como um Enter.
	if cutscene.skip_if_seen and has_been_seen(cutscene):
		_skip()
		return

	_run_step()


func is_running() -> bool:
	return _running


## True se a cutscene já terminou (ou foi pulada) nesta partida.
func has_been_seen(cutscene: CutsceneData) -> bool:
	return _seen.has(_seen_key(cutscene))


## Esquece as cutscenes vistas. Chamado quando uma fase começa (nova partida).
func reset_seen() -> void:
	_seen.clear()


func _seen_key(cutscene: CutsceneData) -> String:
	return cutscene.resource_path if not cutscene.resource_path.is_empty() else str(cutscene.get_instance_id())


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
	_effects_token += 1
	TalkManager.skip_all()
	if _cutscene:
		_seen[_seen_key(_cutscene)] = true

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

	# Step marcado para pular em repetição: segue direto para o próximo.
	if step.skip_if_seen and has_been_seen(_cutscene):
		_advance()
		return

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

	elif step is StepFade:
		_run_step_fade(step as StepFade)

	elif step is StepCall:
		_run_step_call(step as StepCall)

	elif step is StepEffects:
		_run_step_effects(step as StepEffects)

	elif step is StepMusic:
		_run_step_music(step as StepMusic)

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

	# SFX/FX opcionais junto com a animação (no início do step).
	_apply_effects(step.effects, step.target_group, step.wait_to_finish or has_master_timer)

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


## Fade de tela via ScreenFade. Com wait_to_finish, avança quando o fade termina.
func _run_step_fade(step: StepFade) -> void:
	var token := _step_token

	if step.mode == StepFade.Mode.FADE_OUT:
		ScreenFade.fade_out(step.duration)
	else:
		ScreenFade.fade_in(step.duration)

	if step.wait_to_finish and step.duration > 0.0:
		ScreenFade.fade_finished.connect(_advance_if_current.bind(token), CONNECT_ONE_SHOT)
	else:
		_advance_if_current(token)


## Chama um método em todos os nós do grupo e avança. Nunca espera nada:
## se nenhum nó tiver o método, avisa e segue (não trava a sequência).
func _run_step_call(step: StepCall) -> void:
	var called := false
	for target in get_tree().get_nodes_in_group(step.target_group):
		if target.has_method(step.method):
			target.call(step.method)
			called = true

	if not called:
		push_warning("[CutsceneSequencer] StepCall: nenhum nó do grupo '%s' tem o método '%s' — avançando." % [step.target_group, step.method])
	_advance()


## SFX e FX sozinhos. Avança na hora, ou depois de duration (o som em loop vale até lá).
func _run_step_effects(step: StepEffects) -> void:
	var token := _step_token
	_apply_effects(step.effects, "", step.duration > 0.0)
	if step.duration > 0.0:
		get_tree().create_timer(step.duration).timeout.connect(_advance_if_current.bind(token))
	else:
		_advance_if_current(token)


## Troca ou para a música atual e avança.
func _run_step_music(step: StepMusic) -> void:
	if step.action == StepMusic.Action.STOP:
		SoundManager.stop_music()
	elif step.music_id.is_empty():
		push_warning("[CutsceneSequencer] StepMusic PLAY sem music_id — avançando.")
	else:
		SoundManager.play_music(step.music_id, step.volume)
	_advance()


# ── Efeitos (SFX/FX) ─────────────────────────────────────────

## Dispara o FX e inicia o som (com burst/repetição) de um CutsceneEffects.
## default_fx_group: onde o FX nasce quando o resource não define fx_target_group.
## step_has_duration: se o step dura algum tempo (para o aviso do som em loop).
func _apply_effects(effects: CutsceneEffects, default_fx_group: String, step_has_duration: bool) -> void:
	if not effects:
		return
	# Cancelamento da sequência: vale enquanto este step estiver ativo. Quando ele termina
	# (ou a cutscene acaba/é pulada/é substituída), spawns pendentes de FX e SFX não nascem.
	var token := _effects_token
	var cancel := func() -> bool: return not _running or token != _effects_token
	_spawn_effect_fx(effects, default_fx_group, cancel)
	if effects.sfx_id.is_empty():
		return
	if effects.sfx_until_end and not step_has_duration:
		push_warning("[CutsceneSequencer] sfx_until_end em um step que termina na hora — o som toca uma vez só. Dê duração ao step.")
	_play_effect_sfx(effects, token)


func _spawn_effect_fx(effects: CutsceneEffects, default_group: String, cancel: Callable) -> void:
	if not effects.fx:
		return

	var group := effects.fx_target_group if not effects.fx_target_group.is_empty() else default_group
	var spawned := false
	if not group.is_empty():
		for target in get_tree().get_nodes_in_group(group):
			if target is Node2D:
				var node := target as Node2D
				ParticleFX.spawn_at(effects.fx, node.global_position + effects.fx_offset, Vector2.ZERO, node, cancel)
				spawned = true
		if not spawned:
			push_warning("[CutsceneSequencer] FX: nenhum nó no grupo '%s' — usando o centro da câmera." % group)

	if spawned:
		return
	var cam := get_tree().get_first_node_in_group("GmCamera") as Node2D
	if cam:
		ParticleFX.spawn_at(effects.fx, cam.global_position + effects.fx_offset, Vector2.ZERO, null, cancel)
	else:
		push_warning("[CutsceneSequencer] FX sem alvo e sem câmera — nada spawnado.")


## Toca o SFX com a MESMA semântica de burst do FX: sfx_count sons INDIVIDUAIS, o início de
## um separado do início do próximo por sfx_interval. Com sfx_interval = 0, todos na hora.
## Com sfx_until_end, repete até o step acabar. Cada espera é seguida de uma checagem: quando
## o step acaba (_effects_token muda) ou a cutscene termina, os sons restantes não tocam.
func _play_effect_sfx(effects: CutsceneEffects, token: int) -> void:
	var total := maxi(effects.sfx_count, 1)
	var slot := 0

	if effects.sfx_until_end and effects.sfx_interval <= 0.0:
		push_warning("[CutsceneSequencer] sfx_until_end precisa de sfx_interval > 0 — o som toca uma vez só.")
		_play_sfx_slot(effects)
		return

	while _running and token == _effects_token:
		_play_sfx_slot(effects)
		slot += 1
		if not effects.sfx_until_end and slot >= total:
			return
		if effects.sfx_interval > 0.0:
			await get_tree().create_timer(effects.sfx_interval).timeout
		# sfx_interval == 0: o próximo som do burst começa na hora (mesmo frame).


## Um "slot" do burst. Anti-empilhamento: se já há sfx_max_overlap instâncias tocando, este
## slot é PULADO (não adiado), mantendo a cadência do burst igual à do FX.
func _play_sfx_slot(effects: CutsceneEffects) -> void:
	if effects.sfx_max_overlap > 0 \
			and SoundManager.get_active_sfx_count(effects.sfx_id) >= effects.sfx_max_overlap:
		return
	SoundManager.play_sfx(effects.sfx_id, effects.sfx_volume, effects.sfx_pitch)


func _advance() -> void:
	_effects_token += 1
	_step_index += 1
	_run_step()


func _on_dialogue_finished() -> void:
	if not _running:
		return
	_advance()


func _finish() -> void:
	var finished_cutscene := _cutscene   # guarda antes de limpar
	_running = false
	_effects_token += 1
	if finished_cutscene:
		_seen[_seen_key(finished_cutscene)] = true
	GameManager.set_input_mode(GameManager.InputMode.PLAYER)
	InputManager.can_process_player_input = true
	_cutscene = null
	cutscene_finished.emit(finished_cutscene)
	
# IMPORTANTE: emitir DEPOIS de limpar _cutscene, mas com a referência
# que guardamos antes — assim qualquer listener sabe qual cutscene acabou
# sem depender de _cutscene ainda estar preenchido.
