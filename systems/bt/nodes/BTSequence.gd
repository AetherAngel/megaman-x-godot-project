# systems/bt/nodes/BTSequence.gd
class_name BTSequence
extends BTNode

## Executa os filhos em ordem.
## Se todos retornam SUCCESS → SUCCESS.
## Se algum retorna FAILURE → FAILURE imediato (reset).
## Se algum retorna RUNNING → RUNNING (retoma do mesmo filho no próximo frame).

@export var children: Array[BTNode] = []

var _current: int = 0


func tick(actor: Node, blackboard: BTBlackboard) -> Status:
	while _current < children.size():
		var result := children[_current].tick(actor, blackboard)
		match result:
			Status.RUNNING:
				return Status.RUNNING
			Status.FAILURE:
				_current = 0
				return Status.FAILURE
			Status.SUCCESS:
				_current += 1

	_current = 0
	return Status.SUCCESS


func interrupt(actor: Node) -> void:
	if _current < children.size():
		children[_current].interrupt(actor)
	_current = 0
