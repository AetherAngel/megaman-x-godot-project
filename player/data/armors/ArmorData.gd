# player/data/ArmorData.gd
class_name ArmorData
extends Resource

enum ArmorSystem { SKIN_SWAP, LAYER }

@export var armor_id: String = "none"
@export var armor_name: String = "Normal"
@export var armor_system: ArmorSystem = ArmorSystem.SKIN_SWAP

# SKIN_SWAP (Zero, Axl)
@export var animation_folder_override: String = ""

# LAYER (X)
@export var armor_layers: Array[ArmorLayer] = []

# Capabilities dinâmicas (escritas pelo ArmorManager para LAYER, declaradas no .tres para SKIN_SWAP)
@export var has_air_dash: bool = false
@export var has_double_jump: bool = false
@export var can_wall_kick: bool = false
@export var has_nova_strike: bool = false
@export var has_infinite_nova_strike: bool = false
@export var has_charge_weapons: bool = false
@export var has_endless_special: bool = false
@export var damage_reduction: float = 0.0

# Nova Strike — energia e recarga
@export var nova_strike_energy_max: float = 100.0
@export var nova_strike_refuel_rate: float = 8.0    # por segundo (lento)
@export var nova_strike_damage_refuel: float = 25.0  # por hit recebido

# Outros
@export var extra_jump_height: float = 0.0
@export var dash_speed_multiplier: float = 1.0

# Techniques
@export var ground_techniques: Array[InputTechnique] = []
@export var air_techniques: Array[InputTechnique] = []
@export var dash_techniques: Array[InputTechnique] = []
@export var wall_techniques: Array[InputTechnique] = []
