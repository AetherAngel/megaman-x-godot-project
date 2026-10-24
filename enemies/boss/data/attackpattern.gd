class_name AttackPattern
extends Resource

@export_group("Identity")
@export var pattern_id: String = ""

@export_group("Attacks")
## Sequência de ações executadas em ordem — cada uma é um BossAction
## (o mesmo tipo que BTAction já sabe rodar: start/update/finish,
## fases + frame events). Antes era Array[BossAttack] (legado); migrado
## porque BTAction nunca soube executar BossAttack, só BossAction.
@export var attacks: Array[BossAction] = []
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

@export_group("Facing")
## Se true, o boss vira para o jogador ao INICIAR este combo (uma vez, antes do primeiro
## ataque) e mantém essa direção até o último ataque. Um novo combo reavalia.
## Desligue em combos que definem a própria direção (ex: voltar para a arena).
@export var face_player_on_start: bool = true
