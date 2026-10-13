# systems/bt/nodes/BTAction.gd
class_name BTAction
extends BTNode

## Nó folha da Behavior Tree que executa um comportamento do Boss.
##
## Separa a DECISÃO (BT) da EXECUÇÃO (BossAction):
##   BT decide "agora é hora do Hadouken" → BTAction executa HadoukenAction
##
## Dois modos (kind):
##   FIXED  — roda a `action` amarrada neste nó, sem nenhuma resolução.
##            Usado pra MOVE/JUMP/IDLE/etc — a árvore já decidiu tudo só
##            de escolher tickar este nó (mesmo comportamento de sempre,
##            intocado).
##   ATTACK — não tem `action` fixa. Na primeira vez, pergunta pro
##            próprio Boss (actor.select_pattern()) qual AttackPattern
##            está elegível agora (respeitando Phase + condição), e roda
##            a sequência inteira de BossActions daquele pattern, em
##            ordem, antes de reportar SUCCESS pra árvore. É isso que
##            faz "BossIntention: ATTACK" virar comportamento real sem a
##            árvore precisar saber nada sobre Hadouken/Shoryuken/etc.
##
## Ciclo de vida (igual pros dois modos, do ponto de vista da árvore):
##   Primeiro tick: resolve a ação atual, start() → RUNNING
##   Ticks seguintes: update() → RUNNING ou SUCCESS
##   SUCCESS: finish() → nó reseta para o próximo ciclo
##   interrupt(): finish() forçado → limpa estado, sai limpo

enum Kind { FIXED, ATTACK }

@export var kind: Kind = Kind.FIXED
## Usado apenas quando kind = FIXED.
@export var action: BossAction

var _is_running: bool = false

# ── Estado usado apenas quando kind = ATTACK ────────────────────
var _pattern: AttackPattern = null
var _pattern_index: int = 0
var _current_action: BossAction = null


func tick(actor: Node, blackboard: BTBlackboard) -> Status:
	if not _is_running:
		_current_action = _resolve_start_action(actor, blackboard)
		if not _current_action:
			return Status.FAILURE
		_is_running = true
		_current_action.start(actor)

	var done: bool = _current_action.update(actor, blackboard.get_value(BTBlackboard.DELTA, 0.016))
	if not done:
		return Status.RUNNING

	_current_action.finish(actor)

	if kind == Kind.ATTACK:
		return _advance_pattern(actor)

	_is_running = false
	return Status.SUCCESS


## Resolve qual BossAction roda no início de um novo ciclo. Pra ATTACK,
## também escolhe o AttackPattern (uma vez só, aqui) — os avanços
## seguintes dentro do mesmo pattern são _advance_pattern(), não isto.
func _resolve_start_action(actor: Node, blackboard: BTBlackboard) -> BossAction:
	if kind == Kind.FIXED:
		if not action:
			push_error("[BTAction] kind=FIXED sem 'action' configurada.")
		return action

	# kind == ATTACK
	if not actor.has_method("select_pattern"):
		push_error("[BTAction] actor não tem select_pattern() — não é um Boss?")
		return null
	var player_ref = blackboard.get_value(BTBlackboard.PLAYER_REF, null)
	_pattern = actor.select_pattern(player_ref)
	if not _pattern or _pattern.attacks.is_empty():
		return null
	_pattern_index = 0
	return _pattern.attacks[0]


## Chamado quando a BossAction atual do pattern termina. Avança pro
## próximo elo da sequência, ou fecha o pattern (repetindo se loop=true).
func _advance_pattern(actor: Node) -> Status:
	_pattern_index += 1
	if _pattern_index < _pattern.attacks.size():
		_current_action = _pattern.attacks[_pattern_index]
		_current_action.start(actor)
		return Status.RUNNING

	if _pattern.loop:
		_pattern_index = 0
		_current_action = _pattern.attacks[0]
		_current_action.start(actor)
		return Status.RUNNING

	_reset_attack_state()
	_is_running = false
	return Status.SUCCESS


func _reset_attack_state() -> void:
	_pattern = null
	_pattern_index = 0
	_current_action = null


func interrupt(actor: Node) -> void:
	if _is_running and _current_action:
		_current_action.finish(actor)
	_is_running = false
	_reset_attack_state()
