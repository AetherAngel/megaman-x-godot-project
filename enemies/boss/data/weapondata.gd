class_name WeaponData
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
## Resource com os dados da habilidade em si.
## Deixar null para implementar depois.
@export var ability_data: Resource
