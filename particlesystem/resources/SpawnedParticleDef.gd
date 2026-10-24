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
## Intervalo em segundos entre repetições do burst. 0 = apenas uma vez.
## Usado por spawners (FXSpawner) e, com "Wave" ligado, pelo ParticleFX.spawn_at.
@export var repeat_interval: float = 0.0
## WAVE (spawn on original location): se true, ParticleFX.spawn_at repete o burst a cada
## repeat_interval, sempre da posição ORIGINAL (resolvida no momento do spawn) — e não de
## onde as partículas anteriores estão. Combine com burst_count + even_spread para anéis
## radiais repetidos (ex: orbes de morte do MMX). Desligado = comportamento de sempre.
@export var wave: bool = false
## Só vale com Wave ligado: por quanto tempo as ondas duram, em segundos. 0 = até serem
## paradas (ParticleFX.stop_all_continuous, StepCall no grupo "fx_continuous" chamando
## queue_free, ou o respawn do Player).
@export var repeat_duration: float = 0.0
## Se true, só spawna se o owner estiver no chão.
@export var require_grounded: bool = false

@export_group("Position")
## NodePath relativo ao dono para usar como posição de spawn.
## Se vazio, usa a posição passada por código via spawn_at().
@export var marker_path: String = ""
## Se true, atualiza a posição do marker a cada frame enquanto a partícula vive.
## Útil para efeitos que devem "sair do chão" mesmo enquanto o dono se move.
@export var follow_marker: bool = false
## Se true, espelha o X do marker em torno do pivô do dono quando ele está virado para o lado
## oposto ao da arte nativa (o dono precisa ter get_facing_flip(), ex: Boss). Posicione o
## marker no editor na orientação NATIVA da arte. Desligado = comportamento de sempre.
@export var mirror_marker_with_facing: bool = false
## Offset visual do FX
@export var offset: Vector2 = Vector2.ZERO
## Variação aleatória de posição (± por eixo) aplicada a CADA partícula. Serve para
## efeitos espalhados, ex: explosões por cima do corpo de um boss, todas perto umas das
## outras. Combine com burst_count + spawn_interval para explodir ao longo do tempo.
## Zero = todas no mesmo ponto (comportamento anterior).
@export var position_variance: Vector2 = Vector2.ZERO

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
## Se true, as `burst_count` partículas saem em ângulos IGUAIS (em vez de aleatórios).
## spread_angle = 360 → anel completo: 8 partículas = 45° entre cada, a partir de
## base_direction. Abaixo de 360, distribui ao longo do arco (extremos incluídos).
## Combine com velocity_min = velocity_max para um anel regular. O SFX toca uma vez só.
@export var even_spread: bool = false
@export var velocity_min: float = 20.0
@export var velocity_max: float = 60.0
## Gravidade local desta partícula (independente da gravidade do mundo).
@export var gravity: Vector2 = Vector2.ZERO

@export_group("Transform")
@export var scale_start: Vector2 = Vector2.ONE
@export var scale_end: Vector2 = Vector2.ONE
@export var z_index: int = 10
## Rotação FIXA do sprite, em graus, no sentido ANTI-HORÁRIO (positivo gira "para cima").
## 0 = transform original da arte. Ex: arte desenhada para a DIREITA + 90 = aponta para cima.
## (O Godot gira no sentido horário; aqui o sinal é invertido de propósito.)
@export var sprite_rotation_degrees: float = 0.0
## Se true, o sprite também gira para apontar na direção do movimento de cada partícula
## (soma-se à rotação fixa acima). Use sprite_rotation_degrees para compensar para onde a
## arte ORIGINAL aponta: desenhada para a esquerda = 180; para a direita = 0.
@export var rotate_to_direction: bool = false

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
