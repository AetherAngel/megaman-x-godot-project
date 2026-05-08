class_name DynamicPhase
extends Resource

@export_group("Visuals")
@export var sprite_frames: SpriteFrames
@export var animation: String = "default"

@export_group("Timing")
## Duração em segundos. 0 = avança quando a animação terminar.
@export var duration: float = 0.0
## Se true e duration = 0, avança para a próxima fase no fim da animação.
@export var next_phase_on_anim_end: bool = true

@export_group("Movement")
## Velocidade constante desta fase.
@export var velocity: Vector2 = Vector2.ZERO
## Aceleração acumulada por frame (gravidade local da fase).
@export var gravity: Vector2 = Vector2.ZERO
## Se true, herda a velocidade do spawn em vez de usar velocity.
## Útil para fases secundárias que seguem o impulso inicial (ex: estilhaços).
@export var velocity_inherit_from_spawn: bool = false

@export_group("Transform")
@export var phase_scale: Vector2 = Vector2.ONE
