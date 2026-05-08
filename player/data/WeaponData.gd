# resources/player/data/WeaponData.gd
class_name WeaponData
extends Resource

@export var weapon_id: String = "buster"
@export var weapon_name: String = "Buster"
@export var shoot_animation: String = "shoot"
@export var projectile_scene: PackedScene
@export var charge_levels: int = 3
