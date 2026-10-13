# systems/bt/BTTree.gd
class_name BTTree
extends Resource

## Wrapper do nó raiz da Behavior Tree.
## É o Resource que você cria no editor por boss:
##   BT_MagmaDragoon.tres, BT_Iris.tres, BT_Sigma.tres...
##
## O BTRunner chama duplicate(true) neste Resource no _ready(),
## garantindo que cada instância de boss tem sua própria cópia
## com estado completamente isolado.

## Identificação — só para o editor. Ex: "Magma Dragoon BT"
@export var description: String = ""

## Nó raiz da árvore. Normalmente um BTSelector ou BTSequence.
@export var root: BTNode


func tick(actor: Node, blackboard: BTBlackboard) -> BTNode.Status:
	if not root:
		push_error("[BTTree] root não configurado em: '%s'" % description)
		return BTNode.Status.FAILURE
	return root.tick(actor, blackboard)


func interrupt(actor: Node) -> void:
	if root:
		root.interrupt(actor)
