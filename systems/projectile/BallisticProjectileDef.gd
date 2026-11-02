# systems/projectile/BallisticProjectileDef.gd
class_name BallisticProjectileDef
extends Resource

## Configuração de um projétil arremessado em arco (BallisticProjectile): aparência,
## carregamento, trajetória e impacto. É só dado — a lógica mora em BallisticProjectile.gd.
## A mesma lógica serve bola de fogo, bomba, granada... trocando só este Resource.

@export_group("Visuals")
## Opcional. Sem SpriteFrames o projétil desenha um círculo laranja (placeholder).
@export var sprite_frames: SpriteFrames
## Animação enquanto está presa ao dono (carregando) e durante o voo.
## Se o nome não existir, usa a primeira animação do SpriteFrames.
@export var charge_animation: StringName = &"charge"
@export var flight_animation: StringName = &"flight"
@export var z_index: int = 15

@export_group("Charge")
## Soltura automática após este tempo (s) carregando. 0 = só solta com release()
## (ex: FrameEvent RELEASE_OBJECT, na AnimPhase seguinte ao carregamento).
@export var charge_time: float = 0.0

@export_group("Trajectory")
## Gravidade do arremesso (px/s², positiva = para baixo). Define a altura do arco:
## quanto maior, mais alto o arco para o mesmo tempo de voo.
@export var gravity: float = 600.0
## Tempo (s) até chegar ao ponto de destino capturado na soltura. A velocidade inicial
## é calculada para chegar lá exatamente nesse tempo.
@export var flight_time: float = 0.8
## Rede de segurança: some depois deste tempo de voo (s). 0 = DESLIGADA — quem remove o
## projétil é o lifetime do SpawnableObject. Com os dois em 0, a bola voa para sempre.
@export var max_flight_time: float = 0.0

@export_group("Surface notice")
## Raio do projétil (px): hitbox contra o Player e margem à frente do raio de detecção.
@export var radius: float = 6.0
## Layers de física consideradas ao procurar a superfície (padrão 1 = "world").
@export_flags_2d_physics var surface_mask: int = 1
## O projétil ATRAVESSA tudo. Ao cruzar a primeira superfície deste grupo (a lava), avisa
## os ouvintes uma vez e segue voando. "" = nunca avisa.
@export var impact_group: StringName = &"unsafe_ground"
## Quem recebe o aviso: todos os nós deste grupo têm `listener_method` chamado com
## (point: Vector2, normal: Vector2, collider: Node, projectile: Node).
## O projétil não sabe quem escuta nem o que fazem com o aviso.
@export var listener_group: StringName = &"projectile_impact_listener"
@export var listener_method: StringName = &"on_projectile_impact"

@export_group("FX")
## Efeito spawnado quando o projétil acerta o Player (e some).
@export var impact_fx: SpawnedParticleDef

@export_group("Hit")
## Quem a hitbox enxerga (padrão 36 = layers "player" e "playeronly", como a lava).
@export_flags_2d_physics var hit_mask: int = 36
## Layer em que o projétil existe (padrão 137, a mesma dos projéteis do boss).
@export_flags_2d_physics var projectile_layer: int = 137
