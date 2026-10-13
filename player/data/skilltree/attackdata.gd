# player/data/skilltree/AttackData.gd
class_name AttackData
extends Resource

## Dados de um passo do combo básico (usado por SaberAttack).
##
## MUDANÇAS desta versão:
##   elemental_type: String  →  damage_type_id: StringName
##   + damage_units: int     (novo — será lido pelo hitbox quando implementado)
##
## SaberAttack.gd NÃO lê damage_type_id nem damage_units — não há quebra.
## Esses campos ficam preparados para o sistema de hitbox futuro.

# ── Animação ──────────────────────────────────────────────────
## Nome do set de animação. Path final:
##   res://resources/animations/spr_<personagem>_<set_name>.tres
@export var set_name: String = ""
## Nome exato da animação dentro do .tres
@export var animation_name: String = ""
## Animação de unequip dentro do mesmo .tres (opcional)
@export var unequip_animation: String = ""

# ── Timing ────────────────────────────────────────────────────
@export var hold_duration: float = 0.75
@export var cancel_start: float  = 0.45

# ── Combo ─────────────────────────────────────────────────────
## Nome do próximo State — ex: "SaberAttack". Vazio = SaberUnequip.
@export var next_combo_state: String = ""
@export var is_final_combo: bool = false
@export var can_charge: bool = false
@export var is_ultimate: bool = false

# ── Dano ──────────────────────────────────────────────────────
## Unidades de dano base. Será lido pelo hitbox quando implementado.
@export var damage_units: int = 1
## Tipo elemental do dano. Use as constantes de DamageType.
## Substituiu elemental_type: String (era string solta sem validação).
@export var damage_type_id: StringName = DamageType.CONTACT

# ── Áudio ─────────────────────────────────────────────────────
@export var sfx_name: String = ""
@export var sfx_volume: float = 0.0
@export var sfx_pitch: float = 1.0

# ── Unlock ────────────────────────────────────────────────────
## Ataques básicos do combo devem ter unlocked = true no .tres.
@export var unlocked: bool = false
