extends Resource
class_name AttackData

# Parte da ação — ex: "atk_1", "atk_2", "atk_3"
# Path final: res://resources/animations/spr_<personagem>_<set_name>.tres
@export var set_name: String = ""

# Nome exato da animação DENTRO do .tres
@export var animation_name: String = ""

# Animação de unequip dentro do mesmo .tres (opcional)
@export var unequip_animation: String = ""

@export var hold_duration: float = 0.75
@export var cancel_start: float = 0.45

# Nome do próximo State — ex: "SaberAttack". Vazio = SaberUnequip
@export var next_combo_state: String = ""

@export var is_final_combo: bool = false
@export var can_charge: bool = false
@export var is_ultimate: bool = false
@export var elemental_type: String = ""

@export var sfx_name: String = ""  # ex: "snd_ready" — vazio = sem som
@export var sfx_volume: float = 0.0
@export var sfx_pitch: float = 1.0

# Skills começam bloqueadas por padrão
# Ataques básicos do combo devem ter unlocked = true no .tres
@export var unlocked: bool = false
