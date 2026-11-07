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
## O atraso só decide QUANDO o FX aparece, não ONDE: se a posição depende do dono (marker_path,
## offset ou follow_marker), ela é resolvida quando o atraso termina e o FX nasce uma única vez,
## já no lugar certo — sem nascer em um ponto e ser corrigido depois. Sem nenhuma dessas, a
## posição continua sendo a de quando o spawn foi chamado.
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
## NodePath relativo ao dono para usar como posição de spawn. Aceita qualquer Node2D que já
## exista no dono (ex: "Sprite"), não só Marker2D: dá para ancorar sem criar nós novos.
## Se vazio, usa a posição passada por código via spawn_at() (o pivô do dono, nos ataques).
@export var marker_path: String = ""
## Se true, o FX acompanha o dono enquanto vive: a cada frame, a posição é a referência atual
## (o marker, se marker_path existir; senão o pivô do dono) + o deslocamento que o FX tinha no
## nascimento (já com offset e position_variance). Não precisa de marker. Uma virada do dono
## re-espelha o deslocamento no mesmo frame (se mirror_marker_with_facing estiver ligado).
## Enquanto segue, o FX não tem movimento próprio (velocity e gravity são ignoradas). Se o dono
## ou o marker forem liberados, para de seguir e termina normalmente (fade e lifetime).
## A arte (inherit_facing) é decidida só no nascimento. Não vale para Wave: ondas nascem
## sempre do ponto original. Desligado = o FX nasce relativo ao dono e fica independente.
@export var follow_marker: bool = false
## Se true, espelha o X da POSIÇÃO (do marker, do offset e do deslocamento do follow) quando o
## dono está virado para o lado oposto ao da arte NATIVA dele. O dono precisa ter
## get_facing_flip() (ex: Boss), que devolve -1 nesse caso; cada personagem tem a sua orientação
## nativa. Posicione marker e offset olhando para a arte como ela foi desenhada. Dono sem
## get_facing_flip() (ex: Player) não espelha. Espelhar a POSIÇÃO é independente de espelhar a
## ARTE do FX (inherit_facing). Desligado = comportamento de sempre.
@export var mirror_marker_with_facing: bool = false
## Deslocamento do FX em relação ao ponto de referência: o marker (se houver) ou a posição
## passada (o pivô do dono, nos ataques). Aplicado por ParticleFX.spawn_at e spawn_continuous
## quando há `owner`; sem owner a posição já é final e o offset é ignorado. Espelha o X como o
## marker (mirror_marker_with_facing). Permite regiões relativas ao dono sem criar Marker2D.
## Atenção: ParticleFX.create_spawner NÃO aplica este campo; quem chama o usa como posição local
## do spawner (ex: o Dash).
@export var offset: Vector2 = Vector2.ZERO
## Variação aleatória de posição (± por eixo) aplicada a CADA partícula. Serve para
## efeitos espalhados, ex: explosões por cima do corpo de um boss, todas perto umas das
## outras. Combine com burst_count + spawn_interval para explodir ao longo do tempo.
## Zero = todas no mesmo ponto (comportamento anterior). Com follow_marker, a variação de cada
## partícula é preservada enquanto ela acompanha o dono.
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
## Evita hardcodar a direção no código para cada efeito. Também espelha a ARTE (flip_h): a arte
## do FX deve ser desenhada voltada para a DIREITA. Decidido no nascimento. Não move a posição:
## para isso existe mirror_marker_with_facing.
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
