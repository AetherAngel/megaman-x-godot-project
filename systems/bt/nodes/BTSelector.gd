# systems/bt/nodes/BTSelector.gd
class_name BTSelector
extends BTNode

## Tenta os filhos em ordem até um ter sucesso.
## Se algum retorna SUCCESS → SUCCESS imediato (reset).
## Se todos retornam FAILURE → FAILURE.
## Se algum retorna RUNNING → RUNNING (retoma do mesmo filho no próximo frame).
##
## Uso típico: escolher entre fases ou entre ataques por prioridade.
##   Selector
##   ├── Sequence "fase fúria"   ← tenta primeiro
##   └── Sequence "fase normal"  ← fallback

@export var children: Array[BTNode] = []

var _current: int = 0


func tick(actor: Node, blackboard: BTBlackboard) -> Status:
	while _current < children.size():
		var result := children[_current].tick(actor, blackboard)
		match result:
			Status.RUNNING:
				return Status.RUNNING
			Status.SUCCESS:
				_current = 0
				return Status.SUCCESS
			Status.FAILURE:
				_current += 1

	_current = 0
	return Status.FAILURE


func interrupt(actor: Node) -> void:
	if _current < children.size():
		children[_current].interrupt(actor)
	_current = 0
