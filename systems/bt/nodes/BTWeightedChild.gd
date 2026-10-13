# systems/bt/nodes/BTWeightedChild.gd
class_name BTWeightedChild
extends Resource

## Um candidato dentro de um BTRandomWeighted.
##
## condition é checada ANTES do sorteio, sem nenhum side effect —
## BTCondition nunca muta estado nem retorna RUNNING, então é seguro
## "espiar" ela pra filtrar elegibilidade sem executar nada de fato.
## Vazio (null) = sempre elegível.
##
## child é o que de fato roda se este candidato for sorteado.

@export var condition: BTCondition
@export var child: BTNode
@export var weight: float = 1.0
