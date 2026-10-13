# systems/damage/DamageResistanceTable.gd
class_name DamageResistanceTable
extends Resource

## Tabela de resistência/fraqueza de um Boss por tipo de dano.
##
## Fiel ao MMX original: os valores são UNIDADES FINAIS de dano,
## não multiplicadores. O boss recebe exatamente esse valor.
##
##   0  = imune (não recebe dano desse tipo)
##   1  = dano normal
##   2  = dano moderado
##   4  = fraqueza leve
##   8  = fraqueza forte (arma da fraqueza principal)
##
## Crie um .tres por boss em:
##   res://enemies/boss/data/resistance_tables/
##
## Exemplo de configuração (Chill Penguin):
##   entries = {
##     &"fire":     8,   ← fraqueza ao Fire Wave
##     &"ice":      0,   ← imune ao próprio elemento
##     &"buster":   2,
##     &"contact":  0,
##   }
##   default_damage = 1  ← qualquer tipo não listado causa 1 unidade

## Mapa StringName → unidades de dano.
## Deixe tipos ausentes para usar default_damage.
@export var entries: Dictionary = {}

## Dano padrão para qualquer tipo não listado na tabela.
## Normalmente 1 unidade (dano mínimo, como no MMX original).
@export var default_damage: int = 1
