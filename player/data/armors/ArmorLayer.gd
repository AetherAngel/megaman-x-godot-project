# player/data/ArmorLayer.gd
class_name ArmorLayer
extends Resource

@export var slot: String = ""

# Capabilities que essa peça concede ao ser equipada
@export var has_air_dash: bool = false
@export var has_double_jump: bool = false
@export var can_wall_kick: bool = false
@export var damage_reduction: float = 0.0
@export var has_nova_strike: bool = false
@export var has_infinite_nova_strike: bool = false  # ultimate_armor only
@export var has_charge_weapons: bool = false
@export var has_endless_special: bool = false
