# resources/player/data/PlayerCharacterData.gd
class_name PlayerCharacterData
extends Resource

@export var character_id: String = "X"
@export var display_name: String = "Mega Man X"
@export var base_folder: String = "spr_x"

@export var armor_name: String = "fourth_armor"   # ← Aqui você digita o nome da armadura

@export var default_weapon: String = "buster"
@export var special_weapon: String = "buster"

# Caminho montado automaticamente
@export var default_armor_path: String = ""   # deixe vazio, vamos calcular

@export var can_air_dash: bool = false
@export var can_double_jump: bool = false
@export var can_wall_kick: bool = true
@export var skill_tree: SkillTree

# =========================
# CHARGE SYSTEM
# =========================
@export var charge_input: String = "shoot"         # "shoot" (X) ou "special_weapon" (Zero)
@export var charge_lv1_time: float = 0.75          # segundos para lv1
@export var charge_lv2_time: float = 2.0           # segundos para lv2
@export var charge_max_level: int = 2              # X=2, Zero=1
@export var has_stock: bool = false                # arms main do X
@export var has_plasma: bool = false               # arms alt do X (futuro)
 
# =========================
# BUSTER LAYER
# =========================
@export var buster_folder: String = "spr_x"       # prefixo para achar os .tres do buster
# ex: "spr_x"   → spr_x_idle_shoot.tres
#     "spr_zero" → spr_zero_idle_shoot.tres




# Função que monta o caminho quando o recurso é carregado
func _init() -> void:
	if armor_name != "":
		default_armor_path = "res://player/data/armors/" + armor_name + ".tres"
	else:
		default_armor_path = "res://player/data/armors/armor_normal.tres"
