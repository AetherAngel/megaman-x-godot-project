# autoload/GameManager.gd
extends Node

var GameVersion: String = "0.0.5"

enum GameState {
	BOOT,
	DISCLAIMER,
	INTRO_VIDEO,
	MAIN_MENU,
	PLAYER_SELECT,
	STAGE_SELECT,
	IN_STAGE,
	CUTSCENE,
	# ── Boss flow — em ordem de execução ──────────────────────
	BOSS_INTRO,          # sem input — cutscene + diálogo de entrada
	BOSS_PRESENTATION,   # sem input — nome do boss, HP bar enchendo
	BOSS_FIGHT,          # player tem controle total
	BOSS_DEATH,          # sem input — animação de morte do boss
	BOSS_FINAL_DIALOGUE, # sem input — diálogo final (Iris, Double...)
	WEAPON_GET,          # sem input — anim de complete, sai da arena
	WEAPON_GET_SCREEN,   # tela de informações da arma
	# ──────────────────────────────────────────────────────────
	STAGE_CLEAR,
	SHOP,
	EQUIP,
	SAVE_MENU
}

enum InputMode {
	MENU,
	PLAYER
}

var current_state: GameState      = GameState.BOOT
var current_input_mode: InputMode = InputMode.MENU
var current_stage_id: String      = ""
var current_player: String        = "X"
var is_paused: bool               = false

var active_checkpoint: Checkpoint = null

# ── Boss flow ─────────────────────────────────────────────────
## Referência ao boss atual — setada pelo boss no seu _ready().
var current_boss: Boss = null

signal state_changed(new_state)
signal input_mode_changed(new_mode)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_game_flow()


# ============================================================
# PAUSE
# ============================================================

func _get_pause_sprite() -> TextureRect:
	var nodes = get_tree().get_nodes_in_group("pause_png")
	if nodes.size() > 0:
		return nodes[0]
	return null


func _input(event: InputEvent) -> void:
	# Pause só disponível em stage e durante o combate com boss.
	if current_state != GameState.IN_STAGE and current_state != GameState.BOSS_FIGHT:
		return
	if event.is_action_pressed("pause"):
		if is_paused: _unpause()
		else:         _pause()


func _pause() -> void:
	is_paused = true
	get_tree().paused = true
	SoundManager.play_sfx("snd_pause")

	var sprite := _get_pause_sprite()
	print("🔍 Pause sprite encontrado: ", sprite)
	if not sprite:
		return

	print("🖼️ Textura: ", sprite.texture)
	print("📐 Tex size: ", sprite.texture.get_size())

	if not sprite.texture:
		sprite.texture = load("res://resources/pause.png")

	var tex_size = sprite.texture.get_size()
	sprite.size = tex_size
	sprite.position = Vector2(
		(398.0 - tex_size.x) / 2.0,
		(224.0 - tex_size.y) / 2.0
	)

	print("📍 Position: ", sprite.position)
	print("📏 Size: ", sprite.size)

	sprite.modulate = Color(1, 1, 1, 0)
	sprite.visible  = true

	print("👁️ Visible: ", sprite.visible)

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)


func _unpause() -> void:
	is_paused = false
	get_tree().paused = false

	var sprite := _get_pause_sprite()
	if not sprite or not sprite.visible:
		return

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.2)
	await tween.finished
	sprite.visible = false


# ============================================================
# GAME FLOW
# ============================================================

func start_game_flow() -> void:
	await get_tree().create_timer(0.5).timeout
	change_state(GameState.PLAYER_SELECT)


func change_state(new_state: GameState) -> void:
	if is_paused:
		_unpause()

	current_state = new_state
	state_changed.emit(new_state)

	# ── Input mode ────────────────────────────────────────────
	# BOSS_FIGHT é o único state do boss flow com input do player.
	# Todos os outros travam o input até a transição correta.
	match new_state:
		GameState.MAIN_MENU, GameState.PLAYER_SELECT, GameState.STAGE_SELECT, \
		GameState.SHOP, GameState.EQUIP, GameState.SAVE_MENU,                 \
		GameState.BOSS_INTRO, GameState.BOSS_PRESENTATION,                    \
		GameState.BOSS_DEATH, GameState.BOSS_FINAL_DIALOGUE,                  \
		GameState.WEAPON_GET, GameState.WEAPON_GET_SCREEN:
			set_input_mode(InputMode.MENU)
			InputManager.can_process_player_input = false

		GameState.IN_STAGE, GameState.BOSS_FIGHT:
			set_input_mode(InputMode.PLAYER)
			InputManager.can_process_player_input = true

	# ── Música ───────────────────────────────────────────────
	match new_state:
		GameState.MAIN_MENU, GameState.PLAYER_SELECT:
			SoundManager.play_music("mmx4-select3", -25.0)

	# ── Navegação de cena ────────────────────────────────────
	match new_state:
		GameState.STAGE_SELECT:
			get_tree().change_scene_to_file("res://stage_select.tscn")
		GameState.PLAYER_SELECT:
			get_tree().change_scene_to_file("res://Menus/player_select.tscn")
		GameState.SHOP:
			get_tree().change_scene_to_file("res://shop.tscn")
		GameState.EQUIP:
			get_tree().change_scene_to_file("res://equip.tscn")
		GameState.SAVE_MENU:
			get_tree().change_scene_to_file("res://save_menu.tscn")
		GameState.IN_STAGE:
			start_stage()
		GameState.WEAPON_GET_SCREEN:
			_open_weapon_get_screen()
		GameState.STAGE_SELECT:
			_finish_boss_flow()


func set_input_mode(new_mode: InputMode) -> void:
	if current_input_mode == new_mode:
		return
	current_input_mode = new_mode
	input_mode_changed.emit(new_mode)
	print("🔄 Input Mode alterado → ", InputMode.keys()[new_mode])

	if new_mode != InputMode.PLAYER:
		InputManager.shoot_buffer = 0.0


# ============================================================
# STAGE
# ============================================================

func start_stage(stage_id: String = "test") -> void:
	SoundManager.stop_music()
	current_stage_id = stage_id
	print("🎮 Iniciando stage: " + stage_id)
	SoundManager.play_stage_music(stage_id)

	var stage_path = "res://levels/test_stage/test_stage.tscn"
	var packed = load(stage_path)

	if packed:
		get_tree().change_scene_to_packed(packed)
		await get_tree().process_frame
		await get_tree().process_frame

		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("play_stage_intro"):
			await get_tree().create_timer(0.2).timeout
			player.play_stage_intro()
	else:
		push_error("❌ Stage não encontrado: " + stage_path)


func go_to_stage_select() -> void:
	change_state(GameState.STAGE_SELECT)


# ============================================================
# BOSS FLOW
# ============================================================

## Chamado pelo boss no seu _ready() para se registrar.
func register_boss(boss: Boss) -> void:
	current_boss = boss
	boss.boss_defeated.connect(_on_boss_defeated)
	print("✅ Boss registrado: ", boss.name)


## Inicia o fluxo de boss — chamado quando o player entra na arena.
func start_boss_intro() -> void:
	if not current_boss or not current_boss.data:
		push_error("GameManager: start_boss_intro chamado sem boss registrado.")
		return

	change_state(GameState.BOSS_INTRO)
	SoundManager.stop_music()

	var cutscene := current_boss.data.intro_cutscene
	if cutscene:
		# CutsceneSequencer cuida do diálogo — ao terminar chama on_finish.
		CutsceneSequencer.play(cutscene, func():
			# Cutscene terminou → BOSS_PRESENTATION.
			# Tomamos o input de volta imediatamente pois o CutsceneSequencer
			# o restaura ao finalizar, mas ainda não é hora do player agir.
			InputManager.can_process_player_input = false
			change_state(GameState.BOSS_PRESENTATION)
		)
	else:
		# Sem cutscene — vai direto para a apresentação.
		change_state(GameState.BOSS_PRESENTATION)


## Chamado quando a HP bar do boss termina de encher (pelo BossHPBar).
func on_boss_presentation_complete() -> void:
	change_state(GameState.BOSS_FIGHT)
	# Inicia a música de batalha da fase 0 do boss.
	if current_boss and current_boss.data and current_boss.data.phases.size() > 0:
		var phase0 := current_boss.data.phases[0]
		if not phase0.phase_music.is_empty():
			SoundManager.play_music(phase0.phase_music)


## Sinal emitido pelo Boss quando HP chega a zero.
func _on_boss_defeated(has_final_dialogue: bool) -> void:
	change_state(GameState.BOSS_DEATH)
	SoundManager.stop_music()
	SoundManager.stop_all_loops()

	# Aguarda a animação de morte do boss (controlada pelo state Death do boss).
	# O state Death emite o sinal death_animation_finished quando terminar.
	if current_boss and current_boss.state_machine:
		current_boss.state_machine.connect(
			"death_animation_finished",
			_on_death_animation_finished.bind(has_final_dialogue),
			CONNECT_ONE_SHOT
		)


func _on_death_animation_finished(has_final_dialogue: bool) -> void:
	if has_final_dialogue and current_boss and current_boss.data.final_dialogue:
		change_state(GameState.BOSS_FINAL_DIALOGUE)
		TalkManager.start(current_boss.data.final_dialogue, func():
			InputManager.can_process_player_input = false
			change_state(GameState.WEAPON_GET)
			_give_weapon_to_player()
		)
	else:
		change_state(GameState.WEAPON_GET)
		_give_weapon_to_player()


func _give_weapon_to_player() -> void:
	if not current_boss or not current_boss.data or not current_boss.data.weapon_reward:
		# Sem recompensa — pula direto para stage select.
		await get_tree().create_timer(1.0).timeout
		change_state(GameState.STAGE_SELECT)
		return

	var weapon := current_boss.data.weapon_reward
	if not weapon.acquire_sfx.is_empty():
		SoundManager.play_sfx(weapon.acquire_sfx)

	# Toca animação de complete no player.
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("play_stage_clear"):
		player.play_stage_clear()

	await get_tree().create_timer(2.0).timeout
	change_state(GameState.WEAPON_GET_SCREEN)


func _open_weapon_get_screen() -> void:
	# O nó WeaponGetScreen escuta state_changed e se mostra quando
	# o state for WEAPON_GET_SCREEN. Ele recebe os dados via current_boss.
	# Quando o player confirma, emite weapon_get_screen_closed.
	var screen := get_tree().get_first_node_in_group("weapon_get_screen")
	if screen and current_boss and current_boss.data.weapon_reward:
		screen.show_weapon(current_boss.data.weapon_reward)
	else:
		# Sem tela implementada ainda — vai para stage select.
		_finish_boss_flow()


## Chamado pela WeaponGetScreen quando o player confirma.
func on_weapon_get_screen_closed() -> void:
	_finish_boss_flow()


func _finish_boss_flow() -> void:
	current_boss = null
	get_tree().change_scene_to_file("res://stage_select.tscn")
