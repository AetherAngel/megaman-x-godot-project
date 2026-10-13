# systems/bt/nodes/BTRandomWeighted.gd
class_name BTRandomWeighted
extends BTNode

## Sorteia um filho por peso entre os candidatos elegíveis.
## Porte de Boss.select_pattern() para dentro da Behavior Tree —
## mesma lógica (filtra por condição, sorteia por peso entre os que
## sobraram), agora expressa como nós em vez de código imperativo.
##
## Uso típico: variar entre golpes disponíveis numa fase, com pesos
## e condições diferentes por golpe.
##   RandomWeighted
##   ├── (condition: player_close,  weight: 3) → Shoryuken
##   ├── (condition: null,          weight: 5) → Hadouken
##   └── (condition: player_far,    weight: 2) → ChargeFire
##
## Resume no mesmo filho se ele retornar RUNNING — não sorteia de
## novo no meio de uma ação em andamento.

@export var children: Array[BTWeightedChild] = []

var _current_child: int = -1


func tick(actor: Node, blackboard: BTBlackboard) -> Status:
	# Já comprometido com um filho em RUNNING — não sorteia de novo.
	if _current_child >= 0 and _current_child < children.size():
		var result := children[_current_child].child.tick(actor, blackboard)
		if result == Status.RUNNING:
			return Status.RUNNING
		_current_child = -1
		return result

	var chosen := _roll(actor, blackboard)
	if chosen < 0:
		return Status.FAILURE

	_current_child = chosen
	var result := children[chosen].child.tick(actor, blackboard)
	if result == Status.RUNNING:
		return Status.RUNNING
	_current_child = -1
	return result


func interrupt(actor: Node) -> void:
	if _current_child >= 0 and _current_child < children.size():
		children[_current_child].child.interrupt(actor)
	_current_child = -1


# ─────────────────────────────────────────────────────────────
# INTERNO
# ─────────────────────────────────────────────────────────────

## Filtra elegíveis (checando condition sem executar nenhuma ação)
## e sorteia por peso entre eles. Retorna -1 se nenhum for elegível.
func _roll(actor: Node, blackboard: BTBlackboard) -> int:
	var eligible: Array[int] = []
	var total_weight := 0.0

	for i in children.size():
		var wc: BTWeightedChild = children[i]
		if not wc.child:
			continue
		if wc.condition and wc.condition.tick(actor, blackboard) != Status.SUCCESS:
			continue
		eligible.append(i)
		total_weight += wc.weight

	if eligible.is_empty() or total_weight <= 0.0:
		return -1

	var roll := randf() * total_weight
	var accumulated := 0.0
	for i in eligible:
		accumulated += children[i].weight
		if roll <= accumulated:
			return i

	return eligible[-1]
