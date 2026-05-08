class_name AttackPattern
extends Resource

@export_group("Identity")
@export var pattern_id: String = ""

@export_group("Attacks")
## Sequência de ataques executados em ordem.
@export var attacks: Array[BossAttack] = []
## Se true, repete o pattern ao terminar.
@export var loop: bool = false

@export_group("Selection")
## Peso de seleção — quanto maior, mais frequente.
## O sistema faz rolagem ponderada entre os patterns da fase.
@export var weight: float = 1.0

## Cooldown em segundos após executar este pattern.
@export var cooldown: float = 1.5

## Condição para este pattern ser elegível.
## Opções: "" (sempre), "player_near_wall", "player_above",
##         "player_below", "player_close", "player_far"
@export var condition: String = ""
