# systems/damage/DamageProfile.gd
class_name DamageProfile
extends Resource

## O que um golpe causa: dano, tipo e tag. Resource compartilhável — o mesmo .tres pode ser
## referenciado por quem precisar dos mesmos valores (ex.: o dano de contato de um ataque).
##
## É o espelho exato do trio do HitComponent, com os mesmos padrões: nada é derivado de
## outro campo nem preenchido por padrão. Neutro de propósito: não conhece Boss, Player,
## projétil nem ataque, e pode ser usado por qualquer sistema que cause dano.

## Dano bruto (raw), na mesma unidade de HitComponent.damage. 0 = sem dano.
@export var damage: float = 0.0

## Tipo do dano. Use as constantes de DamageType (BUSTER, FIRE, CONTACT...).
@export var damage_type_id: StringName = DamageType.CONTACT

## Tag lida pelo Boss para imunidades por fase (BossPhaseData.immune_to). Vazio = sem tag.
@export var damage_tag: String = ""
