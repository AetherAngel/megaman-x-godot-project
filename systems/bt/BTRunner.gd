# systems/bt/BTRunner.gd
class_name BTRunner
extends Node

## Executa a BTTree a cada frame.
## É um Node filho do Boss — adicione como filho direto em Boss.tscn.
##
## Responsabilidades:
##   1. Duplicar a BTTree no _ready() (instância isolada por boss)
##   2. Atualizar o BTBlackboard com contexto do frame
##   3. Chamar tree.tick() a cada _physics_process()
##
## enabled = false: BTRunner para de tickar (usado durante Intro e Death).

@export var tree: BTTree

## Controla se a BT está ativa. Boss.gd liga no fim do Intro,
## desliga em _on_defeated(). Falso por padrão — boss não age durante Intro.
var enabled: bool = false

var _tree_instance: BTTree
var _blackboard: BTBlackboard


func _ready() -> void:
	if not tree:
		push_error("[BTRunner] BTTree não configurada em: '%s'" % get_parent().name)
		return
	# Instância isolada — mudanças não afetam outros bosses.
	_tree_instance = tree.duplicate(true) as BTTree


func _physics_process(delta: float) -> void:
	if not enabled or not _tree_instance:
		return

	var actor := get_parent()
	_update_blackboard(actor, delta)
	_tree_instance.tick(actor, _blackboard)


# ─────────────────────────────────────────────────────────────
# BLACKBOARD
# ─────────────────────────────────────────────────────────────

# Thresholds — mesmos valores que existiam em Boss._pattern_condition_met().
# Fixos por enquanto (aplicam-se a qualquer boss/NPC via BTRunner). Se algum
# boss futuro precisar de um valor diferente, promover para campo exportado
# em BossData é o próximo passo natural — não feito agora por não ter sido
# pedido ainda.
const WALL_MARGIN        := 32.0
const VERTICAL_THRESHOLD := 32.0
const CLOSE_DISTANCE     := 80.0
const FAR_DISTANCE       := 120.0


func _update_blackboard(actor: Node, delta: float) -> void:
	_blackboard = BTBlackboard.new()
	_blackboard.set_value(BTBlackboard.DELTA, delta)

	# HP ratio do HPSystem (se existir)
	var hp_sys := actor.get_node_or_null("HPSystem") as HPSystem
	_blackboard.set_value(
		BTBlackboard.HP_RATIO,
		hp_sys.hp_ratio if hp_sys else 1.0
	)

	# Fase atual do boss
	if actor.get(&"current_phase") != null:
		_blackboard.set_value(BTBlackboard.CURRENT_PHASE, float(actor.current_phase))

	# Posição, referência e distância do player
	var player := actor.get_tree().get_first_node_in_group("player") as Node2D
	if player and actor is Node2D:
		_blackboard.set_value(BTBlackboard.PLAYER_POSITION, player.global_position)
		_blackboard.set_value(BTBlackboard.PLAYER_REF, player)
		_blackboard.set_value(
			BTBlackboard.DISTANCE_PLAYER,
			(actor as Node2D).global_position.distance_to(player.global_position)
		)
		_compute_spatial_flags(actor as Node2D, player)


# Flags espaciais — porte de Boss._pattern_condition_met().
# Escalável: uma condição nova = uma linha aqui + uma const em BTBlackboard.
func _compute_spatial_flags(actor: Node2D, player: Node2D) -> void:
	var diff: Vector2 = player.global_position - actor.global_position

	var near_wall := false
	if actor.get(&"arena_bounds") != null:
		var bounds: Rect2 = actor.arena_bounds
		near_wall = (
			player.global_position.x < bounds.position.x + WALL_MARGIN or
			player.global_position.x > bounds.position.x + bounds.size.x - WALL_MARGIN
		)

	_blackboard.set_value(BTBlackboard.PLAYER_NEAR_WALL, 1.0 if near_wall else 0.0)
	_blackboard.set_value(BTBlackboard.PLAYER_ABOVE, 1.0 if diff.y < -VERTICAL_THRESHOLD else 0.0)
	_blackboard.set_value(BTBlackboard.PLAYER_BELOW, 1.0 if diff.y > VERTICAL_THRESHOLD else 0.0)
	_blackboard.set_value(BTBlackboard.PLAYER_CLOSE, 1.0 if diff.length() < CLOSE_DISTANCE else 0.0)
	_blackboard.set_value(BTBlackboard.PLAYER_FAR, 1.0 if diff.length() > FAR_DISTANCE else 0.0)


# ─────────────────────────────────────────────────────────────
# CONTROLE EXTERNO
# ─────────────────────────────────────────────────────────────

## Interrompe a árvore imediatamente — usado quando o boss morre ou muda de estado.
func stop() -> void:
	enabled = false
	if _tree_instance:
		_tree_instance.interrupt(get_parent())
