class_name DynamicParticleDef
extends Resource

@export_group("Phases")
## Sequência de fases. Cada uma tem sprite, movimento e timing próprios.
## Exemplo gota de lava: fase 0 = pocinha estática, fase 1 = gota caindo.
@export var phases: Array[DynamicPhase] = []

@export_group("Spawn")
## Quantas instâncias spawnar por chamada de spawn_dynamic().
@export var burst_count: int = 1
## Dispersão em graus aplicada ao impulso inicial.
@export_range(0, 360) var spread_angle: float = 0.0
## Range de velocidade do impulso inicial (aplicado à fase 0 se inherit = true).
@export var velocity_min: float = 0.0
@export var velocity_max: float = 0.0

@export_group("Transform")
@export var z_index: int = 10

@export_group("SFX")
## SFX tocado imediatamente ao spawnar o dynamic particle.
@export var play_sfx: bool = false
@export var sfx_id: String = ""
@export var sfx_volume: float = INF
@export var sfx_pitch: float = INF
