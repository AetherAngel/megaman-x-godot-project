# systems/bt/nodes/BTSubtree.gd
class_name BTSubtree
extends BTNode

## Referencia outro BTNode Resource como bloco reutilizável.
## É a "peça de lego" — você cria uma vez e arrasta em qualquer árvore.
##
## Exemplo:
##   st_patrulha_lr.tres → BTSequence com MoverEsq + MoverDir
##   Vários bosses referenciam o mesmo .tres sem compartilhar estado
##   (pois duplicate(true) no BTRunner duplica tudo, incluindo subtrees).

@export var subtree: BTNode


func tick(actor: Node, blackboard: BTBlackboard) -> Status:
	if not subtree:
		push_error("[BTSubtree] subtree não configurado.")
		return Status.FAILURE
	return subtree.tick(actor, blackboard)


func interrupt(actor: Node) -> void:
	if subtree:
		subtree.interrupt(actor)
