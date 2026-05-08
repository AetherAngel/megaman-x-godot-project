class_name SpawnedParticleDef
extends Resource

@export_group("Visuals")
## SpriteFrames com as animações desta partícula.
@export var sprite_frames: SpriteFrames
## Animações disponíveis. Uma é escolhida aleatoriamente por instância.
@export var animations: Array[String] = ["default"]

@export_group("Spawn")
## Quantas partículas spawnam por chamada de spawn_at().
@export var burst_count: int = 1
## Delay em segundos entre cada partícula do burst. 0 = todas simultâneas.
@export var spawn_interval: float = 0.0
## Atraso em segundos antes de qualquer coisa acontecer.
## Útil para sincronizar com animações sem hardcodar timers no código.
@export var spawn_delay: float = 0.0
## Intervalo em segundos para spawnar continuamente. 0 = apenas uma vez.
@export var repeat_interval: float = 0.0

@export_group("Position")
## NodePath relativo ao dono para usar como posição de spawn.
## Se vazio, usa a posição passada por código via spawn_at().
@export var marker_path: String = ""
## Se true, atualiza a posição do marker a cada frame enquanto a partícula vive.
## Útil para efeitos que devem "sair do chão" mesmo enquanto o dono se move.
@export var follow_marker: bool = false

@export_group("Lifetime")
## Tempo de vida base em segundos.
@export var lifetime: float = 0.5
## Variação aleatória ± do lifetime. Cada instância tem vida ligeiramente diferente.
@export var lifetime_variance: float = 0.1

@export_group("Direction")
## Direção base. Ignorada se inherit_normal = true e uma normal for passada.
@export var base_direction: Vector2 = Vector2.UP
## Se true, usa a normal do impacto como direção quando fornecida.
@export var inherit_normal: bool = false
## Se true, herda o facing_right do dono e espelha base_direction.x automaticamente.
## Evita hardcodar a direção no código para cada efeito.
@export var inherit_facing: bool = false
## Arco de dispersão em graus. 0 = todas na mesma dir, 360 = radial completo.
@export_range(0, 360) var spread_angle: float = 30.0
@export var velocity_min: float = 20.0
@export var velocity_max: float = 60.0
## Gravidade local desta partícula (independente da gravidade do mundo).
@export var gravity: Vector2 = Vector2.ZERO

@export_group("Transform")
@export var scale_start: Vector2 = Vector2.ONE
@export var scale_end: Vector2 = Vector2.ONE
@export var z_index: int = 10

@export_group("Color")
@export var modulate_start: Color = Color.WHITE
## Cor final da interpolação. fade_out = true interpola até aqui.
@export var modulate_end: Color = Color.TRANSPARENT
@export var fade_out: bool = true

@export_group("SFX")
## Se true, toca um SFX no momento exato do spawn.
@export var play_sfx: bool = false
## ID do sfx no sounds.json. Tocado imediatamente ao spawnar, não no fim.
@export var sfx_id: String = ""
## Volume override. INF = usa o valor do JSON.
@export var sfx_volume: float = INF
## Pitch override. INF = usa o valor do JSON.
@export var sfx_pitch: float = INF
