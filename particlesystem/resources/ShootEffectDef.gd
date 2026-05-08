class_name ShootEffectDef
extends Resource

@export_group("Visuals")
@export var sprite_frames: SpriteFrames
@export var animation: String = "shoot_flash"

@export_group("Transform")
## Offset relativo ao ponto de spawn do projétil.
@export var offset: Vector2 = Vector2(15, 0)
@export var base_scale: Vector2 = Vector2.ONE
@export var z_index: int = 15
## Se true, espelha o offset.x quando o personagem vira para a esquerda.
@export var flip_with_facing: bool = true

@export_group("Lifetime")
## Duração em segundos. Normalmente muito curto (0.05–0.15s).
## Se a animação terminar antes, o efeito some automaticamente.
@export var lifetime: float = 0.08

@export_group("SFX")
## Se true, toca um SFX no momento exato do spawn do flash.
@export var play_sfx: bool = false
@export var sfx_id: String = ""
@export var sfx_volume: float = INF
@export var sfx_pitch: float = INF
