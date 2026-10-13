# autoload/BossFlowManager.gd
extends Node

## Responsável por TODO o fluxo do Boss.
## GameManager só precisa saber quando player entra na arena e quando
## o WeaponGetScreen termina.

var _boss: Boss
var _intro_cutscene: CutsceneData  # referência guardada para verificação



# ─────────────────────────────────────────────────────────────
# ENTRADA — chamado pelo ArenaFloorTrigger
# ─────────────────────────────────────────────────────────────

func begin(boss: Boss) -> void:
	_boss = boss
	_boss.boss_defeated.connect(_on_boss_defeated, CONNECT_ONE_SHOT)

	var cam := get_tree().get_first_node_in_group("GmCamera") as StablePixelCamera
	if cam:
		# Se o pan já terminou antes de begin() ser chamado (timing raro),
		# _pan_done estará true e começamos direto.
		if cam.pan_done:
			print("[BossFlowManager] Pan já terminou — começa direto.")
			_start_intro_cutscene()
		else:
			print("[BossFlowManager] Aguardando pan da câmera...")
			cam.pan_finished.connect(_on_camera_pan_finished, CONNECT_ONE_SHOT)
	else:
		print("[BossFlowManager] Sem câmera — começa direto.")
		_start_intro_cutscene()


func _on_camera_pan_finished() -> void:
	print("[BossFlowManager] Pan terminou — iniciando cutscene.")
	_start_intro_cutscene()


# ─────────────────────────────────────────────────────────────
# BOSS_INTRO — intro_cutscene
# ─────────────────────────────────────────────────────────────

func _start_intro_cutscene() -> void:
	if not _boss or not _boss.data:
		push_error("[BossFlowManager] boss ou boss.data nulo em _start_intro_cutscene.")
		return

	GameManager.change_state(GameManager.GameState.BOSS_INTRO)
	SoundManager.stop_music()

	_intro_cutscene = _boss.data.intro_cutscene

	if _intro_cutscene:
		print("[BossFlowManager] Iniciando cutscene: ", _intro_cutscene.resource_path)
		# Conecta DEPOIS de guardar a referência — e verifica no callback
		# se foi ESSA cutscene que terminou (não outra que estava rodando).
		CutsceneSequencer.cutscene_finished.connect(_on_intro_cutscene_finished, CONNECT_ONE_SHOT)
		CutsceneSequencer.play(_intro_cutscene)
		#var _sprite: AnimatedSprite2D = _boss.sprite
		#_sprite.play("magma_dragoon_intro")
	else:
		print("[BossFlowManager] Sem cutscene configurada — indo direto pra apresentação.")
		_start_presentation()


func _on_intro_cutscene_finished(finished_cutscene: CutsceneData) -> void:
	# Verifica se foi a cutscene do boss que terminou — não outra
	# que estava rodando por coincidência de timing.
	if finished_cutscene != _intro_cutscene:
		push_warning("[BossFlowManager] cutscene_finished disparou para cutscene errada — ignorando.")
		# Reconecta para aguardar a certa
		CutsceneSequencer.cutscene_finished.connect(_on_intro_cutscene_finished, CONNECT_ONE_SHOT)
		return

	print("[BossFlowManager] Cutscene de intro terminou — iniciando apresentação.")
	_intro_cutscene = null
	_start_presentation()


# ─────────────────────────────────────────────────────────────
# BOSS_PRESENTATION
# ─────────────────────────────────────────────────────────────

func _start_presentation() -> void:
	print("[BossFlowManager] Começando Boss Presentation.")
	GameManager.change_state(GameManager.GameState.BOSS_PRESENTATION)


func on_presentation_complete() -> void:
	print("[BossFlowManager] Presentation complete — iniciando luta.")
	GameManager.change_state(GameManager.GameState.BOSS_FIGHT)

	if _boss and _boss.data and _boss.data.phases.size() > 0:
		var phase0 := _boss.data.phases[0]
		if not phase0.phase_music.is_empty():
			SoundManager.play_music(phase0.phase_music)

	if _boss and _boss.bt_runner:
		_boss.bt_runner.enabled = true


# ─────────────────────────────────────────────────────────────
# BOSS_DEATH
# ─────────────────────────────────────────────────────────────

func _on_boss_defeated(has_final_dialogue: bool) -> void:
	GameManager.change_state(GameManager.GameState.BOSS_DEATH)
	SoundManager.stop_music()
	SoundManager.stop_all_loops()

	# TODO: aguardar signal death_animation_finished do Death state.
	await get_tree().create_timer(2.0).timeout

	if has_final_dialogue and _boss and _boss.data.final_dialogue:
		GameManager.change_state(GameManager.GameState.BOSS_FINAL_DIALOGUE)
		TalkManager.start(_boss.data.final_dialogue, func():
			_give_weapon()
		)
	else:
		_give_weapon()


# ─────────────────────────────────────────────────────────────
# WEAPON GET
# ─────────────────────────────────────────────────────────────

func _give_weapon() -> void:
	if not _boss or not _boss.data or not _boss.data.weapon_reward:
		await get_tree().create_timer(1.0).timeout
		GameManager.change_state(GameManager.GameState.STAGE_SELECT)
		return

	var weapon := _boss.data.weapon_reward
	if not weapon.acquire_sfx.is_empty():
		SoundManager.play_sfx(weapon.acquire_sfx)

	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("play_stage_clear"):
		player.play_stage_clear()

	GameManager.change_state(GameManager.GameState.WEAPON_GET)
	await get_tree().create_timer(2.0).timeout
	GameManager.change_state(GameManager.GameState.WEAPON_GET_SCREEN)

	var screen := get_tree().get_first_node_in_group("weapon_get_screen")
	if screen and screen.has_method("show_weapon"):
		screen.show_weapon(weapon)
	else:
		GameManager.change_state(GameManager.GameState.STAGE_SELECT)
		_boss = null
