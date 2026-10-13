# ui/hud/hp_bar/behaviors/HPStateHandler.gd
class_name HPStateHandler
extends Node

## Gerenciador de estado dos behaviors visuais da HPBar.
## É filho direto da HPBar no .tscn.
## Instancia e gerencia os behaviors (RefCounted) —
## nenhum behavior precisa estar na scene tree.

const Behaviors = preload("res://ui/hud/hp_bar/behaviors/HPBarBehaviors.gd")

enum HPBarState {
	IDLE,
	DAMAGE,
	HEAL,
	INCREASE,
	BOSS_FILL,
}

var current_state: HPBarState = HPBarState.IDLE
var _behavior  # RefCounted — tipo dinâmico (Godot 4 não suporta typed RefCounted var)
var _bar: Node  # HPBar — referência ao pai


# ─────────────────────────────────────────────────────────────
# GODOT
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_bar = get_parent()
	_behavior = Behaviors.HPIdleBehavior.new()
	_behavior.enter(_bar)


func _process(delta: float) -> void:
	if not _behavior:
		return
	var done: bool = _behavior.process(delta, _bar)
	if done:
		_transition_to_idle()


# ─────────────────────────────────────────────────────────────
# API PÚBLICA — chamada por HPBar
# ─────────────────────────────────────────────────────────────

## Transição para DAMAGE — esconde `amount` unidades do topo.
func start_damage(amount: int) -> void:
	_exit_current()
	current_state = HPBarState.DAMAGE
	var b := Behaviors.HPDamageBehavior.new()
	b.set_pending(amount)
	_behavior = b
	_behavior.enter(_bar)


## Transição para HEAL — mostra `amount` unidades.
func start_heal(amount: int) -> void:
	_exit_current()
	current_state = HPBarState.HEAL
	var b := Behaviors.HPHealBehavior.new()
	b.set_pending(amount)
	_behavior = b
	_behavior.enter(_bar)


## Transição para INCREASE — expande o max exibido em `amount` unidades.
func start_increase(amount: int) -> void:
	_exit_current()
	current_state = HPBarState.INCREASE
	var b := Behaviors.HPIncreaseBehavior.new()
	b.set_pending(amount)
	_behavior = b
	_behavior.enter(_bar)


## Transição para BOSS_FILL — preenche a barra do boss durante BOSS_PRESENTATION.
## fill_speed vem de HPBarConfig.boss_fill_speed.
func start_boss_fill(fill_speed: float) -> void:
	_exit_current()
	current_state = HPBarState.BOSS_FILL
	var b := Behaviors.BossHPBehavior.new()
	b.fill_speed = fill_speed
	_behavior = b
	_behavior.enter(_bar)


func force_idle() -> void:
	_transition_to_idle()


# ─────────────────────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────────────────────

func _exit_current() -> void:
	if _behavior:
		_behavior.exit(_bar)


func _transition_to_idle() -> void:
	_exit_current()
	current_state = HPBarState.IDLE
	_behavior     = Behaviors.HPIdleBehavior.new()
	_behavior.enter(_bar)
