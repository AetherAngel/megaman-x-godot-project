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
# FALHA — o jogador morreu durante a luta
# ─────────────────────────────────────────────────────────────

## Chamado pelo ObjectiveHelper quando o jogador morre em BOSS_FIGHT.
## Devolve o boss ao estado inicial para uma nova tentativa. O fluxo recomeça
## quando o jogador atravessar a porta de novo (ArenaFloorTrigger → begin()).
## A intro_cutscene pula sozinha se estiver marcada com skip_if_seen.
func abort_fight() -> void:
	if not _boss:
		return
	# O begin() conectou boss_defeated com ONE_SHOT: sem desconectar, a próxima
	# tentativa tentaria conectar de novo.
	if _boss.boss_defeated.is_connected(_on_boss_defeated):
		_boss.boss_defeated.disconnect(_on_boss_defeated)
	_boss.reset_for_retry()
	_intro_cutscene = null


# ─────────────────────────────────────────────────────────────
# BOSS_DEATH
# ─────────────────────────────────────────────────────────────

## Pausa entre o golpe final e a fala/cutscene de derrota.
const DEFEAT_BEAT: float = 2.0
## Projéteis a limpar na vitória. Só quem está no grupo é removido — o cenário fica seguro.
const PROJECTILE_GROUP := &"projectile"
## Motivo do lock de HP do Player durante a vitória.
const VICTORY_LOCK := &"victory"


func _on_boss_defeated(has_final_dialogue: bool) -> void:
	GameManager.change_state(GameManager.GameState.BOSS_DEATH)
	SoundManager.stop_music()
	SoundManager.stop_all_loops()

	# Nada pode machucar o Player durante a vitória, e nada da luta deve sobrar na fase.
	_protect_player()
	get_tree().call_group(PROJECTILE_GROUP, "queue_free")

	await get_tree().create_timer(DEFEAT_BEAT).timeout

	# Fala final (se houver). O boss permanece vivo até a defeat_cutscene.
	if has_final_dialogue and _boss and _boss.data.final_dialogue:
		GameManager.change_state(GameManager.GameState.BOSS_FINAL_DIALOGUE)
		TalkManager.start(_boss.data.final_dialogue, _play_defeat_cutscene)
	else:
		_play_defeat_cutscene()


## Animação de derrota → destruição → espera, montada pelo designer em
## BossData.defeat_cutscene. Sem cutscene: destrói o boss direto (alternativa de segurança).
func _play_defeat_cutscene() -> void:
	var cutscene: CutsceneData = _boss.data.defeat_cutscene if _boss and _boss.data else null
	if cutscene:
		CutsceneSequencer.cutscene_finished.connect(_on_defeat_cutscene_finished, CONNECT_ONE_SHOT)
		CutsceneSequencer.play(cutscene)
		return

	if _boss:
		_boss.play_destruction()
		_boss.hide()
	_on_defeat_cutscene_finished(null)


## Fim da derrota do boss → entrega a recompensa e segue para a vitória do Player.
func _on_defeat_cutscene_finished(_cutscene: CutsceneData) -> void:
	_deliver_reward()


## Trava o HP do Player: nada o machuca (ex: sobra de projétil) durante a vitória.
func _protect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var hp := player.get_node_or_null("HPSystem") as HPSystem
	if hp:
		hp.lock(VICTORY_LOCK)


# ─────────────────────────────────────────────────────────────
# WEAPON GET
# ─────────────────────────────────────────────────────────────

## Recompensa: som, marca o boss como derrotado, libera as armas (X e Zero) e salva.
## TODO: o pickup da arma descendo do centro superior da tela até o Player. Enquanto ele
## não existe, a marcação acontece logo depois da destruição do boss.
func _deliver_reward() -> void:
	var weapon: WeaponRewardData = _boss.data.weapon_reward if _boss and _boss.data else null
	if weapon and not weapon.acquire_sfx.is_empty():
		SoundManager.play_sfx(weapon.acquire_sfx)

	GameManager.on_boss_defeated(weapon)
	_play_victory_cutscene()


## Pose de vitória (state Victory) + a victory_cutscene da ficha do personagem (saída).
func _play_victory_cutscene() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("start_victory"):
		player.start_victory()

	var character := player.get("current_character") as PlayerCharacterData if player else null
	var cutscene: CutsceneData = character.victory_cutscene if character else null
	if cutscene:
		CutsceneSequencer.cutscene_finished.connect(_on_victory_cutscene_finished, CONNECT_ONE_SHOT)
		CutsceneSequencer.play(cutscene)
		return

	push_warning("[BossFlowManager] Personagem sem victory_cutscene — pulando a saída do Player.")
	_on_victory_cutscene_finished(null)


func _on_victory_cutscene_finished(_cutscene: CutsceneData) -> void:
	_show_weapon_get_screen()


## TODO: WeaponGetScreen (ainda não existe) e a cena do STAGE_SELECT (também não existe).
## Sem a tela, vai direto para o STAGE_SELECT, como antes.
func _show_weapon_get_screen() -> void:
	var weapon: WeaponRewardData = _boss.data.weapon_reward if _boss and _boss.data else null
	if not weapon:
		GameManager.change_state(GameManager.GameState.STAGE_SELECT)
		_boss = null
		return

	GameManager.change_state(GameManager.GameState.WEAPON_GET_SCREEN)
	var screen := get_tree().get_first_node_in_group("weapon_get_screen")
	if screen and screen.has_method("show_weapon"):
		screen.show_weapon(weapon)
	else:
		GameManager.change_state(GameManager.GameState.STAGE_SELECT)
		_boss = null
