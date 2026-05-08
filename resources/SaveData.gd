# resources/SaveData.gd
class_name SaveData
extends Resource

@export var money: int = 0
@export var lives: int = 3
@export var defeated_bosses: Dictionary = {}
@export var collected_heart_tanks: int = 0
@export var subtanks: int = 0

# Armadura do X
@export var x_equipped_pieces: Array[String] = []
# [] = sem armadura | ["legs"] = só pernas | ["head","body","arms","legs"] = completa
@export var x_armor_id: String = "normal"
# "normal" = armor_normal.tres | "ultimate" = ultimate_armor.tres

# Armadura do Zero
@export var zero_armor_id: String = "normal"
# "normal" = normal_zero.tres | "black_zero" = black_zero.tres
