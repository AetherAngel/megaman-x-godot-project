# systems/bt/BTNode.gd
class_name BTNode
extends Resource

## Classe base para todos os nós da Behavior Tree.
## Cada nó é um Resource — leve, serializável e montável no editor.
## O BTRunner chama duplicate(true) no _ready(), garantindo instâncias isoladas.

enum Status {
	RUNNING,  ## ação em execução, continua no próximo frame
	SUCCESS,  ## concluiu com êxito
	FAILURE,  ## falhou, pai decide o próximo passo
}


## Executa a lógica deste nó para um frame.
## actor:      o Boss/NPC dono desta árvore
## blackboard: contexto do frame (hp, posição do player, etc.)
func tick(_actor: Node, _blackboard: BTBlackboard) -> Status:
	return Status.SUCCESS


## Interrompe este nó e propaga para filhos se necessário.
## Chamado quando a árvore abandona este nó antes de SUCCESS/FAILURE.
func interrupt(_actor: Node) -> void:
	pass
