## Recompensa que o boss dá ao ser derrotado (nome, ícone, som, habilidade).
## NÃO é o WeaponData do Player (player/data/WeaponData.gd), que descreve o
## comportamento da arma (projétil, cargas). Esta aqui só diz O QUE o player ganha.
class_name WeaponRewardData
extends Resource

@export_group("Identity")
@export var weapon_name: String = ""
@export var weapon_id: String = ""       # ex: "fire_wave", "double_cyclone"

@export_group("Weapon Get Screen")
@export var icon: Texture2D
@export var description: String = ""
## Cor de destaque usada na tela de Weapon Get.
@export var accent_color: Color = Color.WHITE

@export_group("Audio")
## SFX tocado ao adquirir a arma.
@export var acquire_sfx: String = "snd_weapon_get"

@export_group("Ability")
## Habilidade que este boss libera para cada personagem (os dois ao mesmo tempo).
## Deixar null para implementar depois.
## X: arma especial.
@export var x_ability: Resource
## Zero: técnica correspondente.
@export var zero_ability: Resource
