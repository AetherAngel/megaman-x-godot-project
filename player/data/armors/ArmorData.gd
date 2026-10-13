# player/data/armors/ArmorData.gd
class_name ArmorData
extends Resource

## MUDANÇA desta versão:
##   ground/air/dash/wall_techniques: Array[InputTechnique]
##   →  Array[TechniqueData]
##
## ATENÇÃO: normal_zero.tres precisa ser recriado.
## Veja o README do Batch 5A para as instruções.

enum ArmorSystem { SKIN_SWAP, LAYER }

@export var armor_id: String = "none"
@export var armor_name: String = "Normal"
@export var armor_system: ArmorSystem = ArmorSystem.SKIN_SWAP

# ── SKIN_SWAP (Zero, Axl) ─────────────────────────────────────
@export var animation_folder_override: String = ""

# ── LAYER (X) ─────────────────────────────────────────────────
@export var armor_layers: Array[ArmorLayer] = []

# ── Capabilities ──────────────────────────────────────────────
@export var has_air_dash: bool = false
@export var has_double_jump: bool = false
@export var can_wall_kick: bool = false
@export var has_nova_strike: bool = false
@export var has_infinite_nova_strike: bool = false
@export var has_charge_weapons: bool = false
@export var has_endless_special: bool = false
@export var damage_reduction: float = 0.0

# ── Nova Strike ───────────────────────────────────────────────
@export var nova_strike_energy_max: float = 100.0
@export var nova_strike_refuel_rate: float = 8.0
@export var nova_strike_damage_refuel: float = 25.0

# ── Outros ────────────────────────────────────────────────────
@export var extra_jump_height: float = 0.0
@export var dash_speed_multiplier: float = 1.0

# ── Técnicas ─────────────────────────────────────────────────
## Cada TechniqueData contém um InputTechnique (input) + dados de dano (outcome).
## Substituiu Array[InputTechnique] — os .tres de InputTechnique são reaproveitados
## como sub-resources dentro de cada TechniqueData.
@export var ground_techniques: Array[TechniqueData] = []
@export var air_techniques:    Array[TechniqueData] = []
@export var dash_techniques:   Array[TechniqueData] = []
@export var wall_techniques:   Array[TechniqueData] = []
