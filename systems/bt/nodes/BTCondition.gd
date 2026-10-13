# systems/bt/nodes/BTCondition.gd
class_name BTCondition
extends BTNode

## Checa uma condição no BTBlackboard.
## Retorna SUCCESS se a condição for verdadeira, FAILURE caso contrário.
## Nunca retorna RUNNING.
##
## Exemplos de uso:
##   key = BTBlackboard.HP_RATIO, op = LESS_THAN,    value = 0.3  → hp < 30%
##   key = BTBlackboard.DISTANCE_PLAYER, op = LESS_EQUAL, value = 80.0 → perto do player
##   key = BTBlackboard.CURRENT_PHASE, op = EQUAL,   value = 1.0  → na fase 1

enum Operator {
	LESS_THAN,     ## <
	LESS_EQUAL,    ## <=
	EQUAL,         ## ==
	GREATER_EQUAL, ## >=
	GREATER_THAN,  ## >
}

## Chave do BTBlackboard a consultar. Use as constantes BTBlackboard.HP_RATIO, etc.
@export var key: StringName = BTBlackboard.HP_RATIO
@export var operator: Operator = Operator.LESS_THAN
@export var value: float = 0.3


func tick(_actor: Node, blackboard: BTBlackboard) -> Status:
	var bv: float = float(blackboard.get_value(key, 0.0))

	var result: bool = false
	match operator:
		Operator.LESS_THAN:     result = bv < value
		Operator.LESS_EQUAL:    result = bv <= value
		Operator.EQUAL:         result = is_equal_approx(bv, value)
		Operator.GREATER_EQUAL: result = bv >= value
		Operator.GREATER_THAN:  result = bv > value

	return Status.SUCCESS if result else Status.FAILURE
