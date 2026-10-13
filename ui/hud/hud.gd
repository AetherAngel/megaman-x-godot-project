# ui/hud/HUD.gd
class_name HUD
extends CanvasLayer

## Coordenador do HUD do player.
## Responsabilidades:
##   - Controlar visibilidade conforme GameManager.state_changed
##   - Conectar PlayerHPBar ao HPSystem do player
##   - Conectar BossHPBar ao HPSystem do boss em BOSS_PRESENTATION
##   - Atualizar ícone do PlayerHPBar na troca de personagem
##
## HIERARQUIA DA CENA (HUD.tscn):
##   HUD (CanvasLayer — este script)
##   ├── PlayerHPBar (instância de HPBar.tscn)
##   └── BossHPBar   (instância de HPBar.tscn)
##
## NÃO contém lógica de HP — é puramente display e coordenação.
## layer = 10 (sempre on top).


# ── Configurações por barra ───────────────────────────────────
## HPBarConfig para a barra do player. Crie player_hpbar_config.tres no editor.
@export var player_bar_config: HPBarConfig
## HPBarConfig para a barra do boss. Crie boss_hpbar_config.tres no editor.
@export var boss_bar_config: HPBarConfig

# ── Nós ───────────────────────────────────────────────────────
@onready var player_hp_bar: HPBar = $PlayerHPBar
@onready var boss_hp_bar:   HPBar = $BossHPBar

# ── States onde o HUD do player é visível ─────────────────────
const _PLAYER_HUD_STATES: Array = [
	GameManager.GameState.IN_STAGE,
	GameManager.GameState.BOSS_INTRO,
	GameManager.GameState.BOSS_PRESENTATION,
	GameManager.GameState.BOSS_FIGHT,
	GameManager.GameState.BOSS_DEATH,
	GameManager.GameState.BOSS_FINAL_DIALOGUE,
	GameManager.GameState.WEAPON_GET,
]

# ── States onde o Boss HUD é visível ─────────────────────────
const _BOSS_HUD_STATES: Array = [
	GameManager.GameState.BOSS_PRESENTATION,
	GameManager.GameState.BOSS_FIGHT,
]

# ── Referências runtime ───────────────────────────────────────
var _player_hp_system: HPSystem
var _boss_hp_system:   HPSystem


# ─────────────────────────────────────────────────────────────
# GODOT
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 10  # always on top

	if !player_hp_bar and !boss_hp_bar:
		print("playerhpbar node and bosshpbar node null!")

	GameManager.state_changed.connect(_on_state_changed)
	CharacterManagement.character_switched.connect(_on_character_switched)

	# Sincroniza com o estado ATUAL do GameManager.
	#
	# BUG QUE ISSO RESOLVE: GameManager.change_state(IN_STAGE) emite state_changed
	# e SÓ DEPOIS chama start_stage() → change_scene_to_packed(), que destrói a
	# cena atual (HUD antigo) e cria uma nova (este HUD). Como este HUD só passa
	# a existir DEPOIS do signal já ter sido emitido, ele nunca recebe a notificação
	# do estado em que o jogo já está — sinais não são retroativos.
	#
	# Chamando _on_state_changed manualmente com o estado atual, garantimos que
	# o HUD novo sempre sincroniza corretamente, independente de quando nasceu.
	_on_state_changed(GameManager.current_state)

	# Conecta ao HPSystem do player após todos os _ready() da cena terminarem.
	# Em Godot 4 os filhos têm _ready() antes do pai (bottom-up),
	# então o HUD (filho do Player) já tem o HPSystem do Player disponível.
	call_deferred("_connect_player_hp")


# ─────────────────────────────────────────────────────────────
# CONEXÃO COM HPSYSTEM DO PLAYER
# ─────────────────────────────────────────────────────────────

func _connect_player_hp() -> void:
	var player := get_parent() as Player
	if not player:
		push_error("[HUD] Pai não é um Player. HUD deve ser filho direto do Player.tscn.")
		return

	_player_hp_system = player.get_node_or_null("HPSystem") as HPSystem
	if not _player_hp_system:
		push_error("[HUD] HPSystem não encontrado no Player.")
		return

	_player_hp_system.units_changed.connect(player_hp_bar._on_units_changed)

	# Inicializa a barra com os valores atuais do HPSystem.
	player_hp_bar.setup(
		player_bar_config,
		_player_hp_system.current_units,
		_player_hp_system.max_units
	)


# ─────────────────────────────────────────────────────────────
# RESPOSTA A EVENTOS
# ─────────────────────────────────────────────────────────────

func _on_state_changed(new_state: GameManager.GameState) -> void:
	player_hp_bar.visible = new_state in _PLAYER_HUD_STATES

	match new_state:
		GameManager.GameState.BOSS_PRESENTATION:
			_connect_boss_hp()
			boss_hp_bar.visible = true
			print("[DEBUG][HUD] current_boss: %s | boss_hp_system: %s | boss_hp_bar.max_units: %d" % [
		GameManager.current_boss, _boss_hp_system, boss_hp_bar.max_units
				])
			boss_hp_bar.state_handler.start_boss_fill(
				boss_bar_config.boss_fill_speed if boss_bar_config else 16.0
			)

		GameManager.GameState.BOSS_DEATH:
			boss_hp_bar.visible = false
			_disconnect_boss_hp()

		_:
			boss_hp_bar.visible = new_state in _BOSS_HUD_STATES


## Conecta a BossHPBar ao HPSystem do boss atual.
func _connect_boss_hp() -> void:
	_disconnect_boss_hp()  # garante que não há conexão duplicada

	if not GameManager.current_boss:
		push_warning("[HUD] BOSS_PRESENTATION sem current_boss registrado.")
		return

	_boss_hp_system = GameManager.current_boss.get_node_or_null("HPSystem") as HPSystem
	if not _boss_hp_system:
		push_error("[HUD] HPSystem não encontrado no Boss.")
		return

	_boss_hp_system.units_changed.connect(boss_hp_bar._on_units_changed)

	boss_hp_bar.setup(
		boss_bar_config,
		0,  # começa visualmente em 0 — BossHPBehavior preenche
		_boss_hp_system.max_units
	)


## Desconecta a BossHPBar do HPSystem do boss (ao fim do combate).
func _disconnect_boss_hp() -> void:
	if not _boss_hp_system:
		return
	if _boss_hp_system.units_changed.is_connected(boss_hp_bar._on_units_changed):
		_boss_hp_system.units_changed.disconnect(boss_hp_bar._on_units_changed)
	_boss_hp_system = null


## Troca de personagem → atualiza ícone da PlayerHPBar.
## O HPSystem já emitirá units_changed automaticamente via HPRegistry.
func _on_character_switched(new_id: StringName) -> void:
	player_hp_bar.set_icon(new_id)
