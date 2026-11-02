# systems/projectile/BallisticProjectile.gd
class_name BallisticProjectile
extends Area2D

## Projétil arremessado em arco, como uma bola de basquete: nasce presa ao dono carregando,
## é solta com release(), captura o alvo UMA vez e voa numa parábola fixa. Sem tracking.
##
## CICLO
##   CHARGING ... segue o dono (quem spawnou). Sem hitbox. Espera release() ou charge_time.
##   FLYING ..... trajetória analítica: p(t) = p0 + v0·t + ½·g·t². Hitbox ligada.
##   DONE ....... acertou o Player e se libera.
##
## O QUE A FAZ SUMIR
##   SÓ o contato com o Player. Terreno, lava, paredes: ela ATRAVESSA tudo. Se ninguém a
##   acertar, quem remove é o lifetime do SpawnableObject (Boss._spawn_object) — ou
##   `max_flight_time`, uma rede de segurança opcional (0 = desligada).
##
## TRAJETÓRIA
##   No release() captura p0 (onde está) e o alvo (posição do Player nesse instante).
##   v0 = (alvo - p0 - ½·g·T²) / T  →  em t = T o projétil está exatamente no alvo.
##   Depois disso nada corrige a rota: se o Player se mover, a bola erra naturalmente.
##
## AVISO DE SUPERFÍCIE (ex: a lava)
##   Atravessar não significa ignorar: ao cruzar a PRIMEIRA superfície do grupo
##   `impact_group` (a lava), o projétil avisa os ouvintes (config.listener_group) com o ponto
##   EXATO de contato — e segue voando. Avisa uma vez só por projétil. Terreno comum não avisa.
##   Todo tick um raio vai da posição anterior à nova (+ o raio da bola à frente), então não
##   perde uma superfície fina em alta velocidade, nem uma lava que está atrás de terreno.
##   O projétil não conhece quem escuta nem o que fazem com o aviso.
##
## Spawn pelo boss: Boss._spawn_object() chama launch() se existir — este script NÃO tem
## launch() de propósito (a bola não sai voando no spawn); a soltura é release().
## Dano/attacker: configurados pelo Boss a partir do SpawnableObject, no HitComponent filho.

## Emitido na soltura, com o alvo capturado.
signal released(target: Vector2)
## Emitido ao cruzar a primeira superfície do `impact_group` (a bola continua voando).
signal surface_crossed(point: Vector2, normal: Vector2, collider: Object)

enum ProjectilePhase { CHARGING, FLYING, DONE }

## Quantos obstáculos de OUTROS grupos o raio atravessa procurando a superfície do aviso.
const _MAX_RAY_HOPS := 8

## O Resource deste projétil. Arraste aqui o .tres.
@export var config: BallisticProjectileDef

var _phase: ProjectilePhase = ProjectilePhase.CHARGING
var _anchor: Node2D = null
var _anchor_offset: Vector2 = Vector2.ZERO
var _anchor_resolved: bool = false
var _charge_elapsed: float = 0.0

var _p0: Vector2 = Vector2.ZERO
var _v0: Vector2 = Vector2.ZERO
var _g: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _surface_notified: bool = false

var _sprite: AnimatedSprite2D = null
var _shape: CollisionShape2D = null
var _hit: HitComponent = null


func _ready() -> void:
	add_to_group(&"projectile")  # limpo na vitória do boss (BossFlowManager)
	if config == null:
		push_error("BallisticProjectile '%s': config ausente." % name)
		set_physics_process(false)
		return

	z_index = config.z_index
	collision_layer = config.projectile_layer
	collision_mask = config.hit_mask
	monitorable = false
	monitoring = false  # sem dano enquanto carrega

	_setup_shape()
	_setup_sprite()
	_hit = get_node_or_null("HitComponent") as HitComponent
	if _hit == null:
		push_warning("BallisticProjectile '%s': sem filho 'HitComponent' — não causará dano." % name)

	body_entered.connect(_on_hit_target)
	area_entered.connect(_on_hit_target)


# ── API pública ──────────────────────────────────────────────

## Solta a bola em direção à posição ATUAL do Player. Só vale carregando; ignora o resto.
func release() -> void:
	if _phase != ProjectilePhase.CHARGING or config == null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		push_warning("BallisticProjectile '%s': nenhum nó no grupo 'player' — nada para mirar." % name)
		queue_free()
		return
	_launch_towards(player.global_position)


## Quem spawnou (HitComponent.attacker, definido pelo Boss). Ouvintes de impacto podem querer.
func get_attacker() -> Node:
	return _hit.attacker if _hit else null


func get_radius() -> float:
	return config.radius if config else 0.0


# ── Ciclo ────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	match _phase:
		ProjectilePhase.CHARGING:
			_process_charging(delta)
		ProjectilePhase.FLYING:
			_process_flying(delta)


func _process_charging(delta: float) -> void:
	if not _anchor_resolved:
		_resolve_anchor()
	if is_instance_valid(_anchor):
		global_position = _anchor.global_position + _anchor_offset
	if config.charge_time > 0.0:
		_charge_elapsed += delta
		if _charge_elapsed >= config.charge_time:
			release()


## O Boss define `attacker` logo DEPOIS do add_child, ainda no mesmo frame — por isso o dono é
## resolvido no primeiro tick (e não no _ready). O offset capturado é o que o SpawnableObject
## colocou entre o boss e a bola. Limite conhecido: se o boss se mover entre o spawn e este
## primeiro tick, o offset sai deslocado por esse (pequeno) movimento — o boss conjura parado.
func _resolve_anchor() -> void:
	_anchor_resolved = true
	var owner_node := get_attacker() as Node2D
	if owner_node:
		_anchor = owner_node
		_anchor_offset = global_position - owner_node.global_position


func _launch_towards(target: Vector2) -> void:
	_p0 = global_position
	_g = Vector2(0.0, config.gravity)
	var flight := maxf(config.flight_time, 0.05)
	_v0 = (target - _p0 - 0.5 * _g * flight * flight) / flight
	_t = 0.0
	_anchor = null  # sem vínculo posterior com o boss
	_phase = ProjectilePhase.FLYING
	monitoring = true
	_play(config.flight_animation)
	released.emit(target)


func _process_flying(delta: float) -> void:
	_t += delta
	var next := _p0 + _v0 * _t + 0.5 * _g * _t * _t
	if not _surface_notified:
		_check_notify_surface(global_position, next)
	global_position = next
	if config.max_flight_time > 0.0 and _t >= config.max_flight_time:
		_finish(global_position, Vector2.ZERO)


## Procura, no trecho percorrido neste tick, uma superfície do `impact_group`. Superfícies de
## outros grupos (terreno) NÃO barram: entram numa lista de exclusão e o raio é lançado de novo,
## até achar a lava ou acabar o que há no caminho. Nada aqui interrompe o voo.
func _check_notify_surface(from: Vector2, to: Vector2) -> void:
	if config.impact_group == &"":
		return
	var motion := to - from
	if motion.length_squared() < 0.0001:
		return
	var query := PhysicsRayQueryParameters2D.create(from, to + motion.normalized() * config.radius, config.surface_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var space := get_world_2d().direct_space_state
	var excluded: Array[RID] = []
	for _hop in _MAX_RAY_HOPS:
		query.exclude = excluded
		var result := space.intersect_ray(query)
		if result.is_empty():
			return
		var collider := result.collider as Node
		if collider and collider.is_in_group(config.impact_group):
			_notify_surface(result.position, result.normal, collider)
			return
		excluded.append(result.rid)   # não é a superfície procurada: atravessa e olha o que vem depois


func _notify_surface(point: Vector2, normal: Vector2, collider: Node) -> void:
	_surface_notified = true
	surface_crossed.emit(point, normal, collider)
	get_tree().call_group(config.listener_group, config.listener_method, point, normal, collider, self)


func _on_hit_target(other: Node) -> void:
	if _phase != ProjectilePhase.FLYING:
		return
	# Só algo que PODE levar dano consome a bola (mesmo critério do HitBus). A máscara inclui a
	# layer "playeronly": uma parede/porta ali não pode fazê-la sumir. O próprio dono também não.
	if other == get_attacker() or not other.has_method("take_damage"):
		return
	if _hit:
		_hit.report(other)  # o HitBus valida o alvo (descarta o próprio boss, paredes...)
	_finish(global_position, Vector2.ZERO)   # o Player é a ÚNICA coisa que consome o projétil


func _finish(point: Vector2, normal: Vector2) -> void:
	if _phase == ProjectilePhase.DONE:
		return
	_phase = ProjectilePhase.DONE
	set_physics_process(false)
	monitoring = false
	if config.impact_fx:
		ParticleFX.spawn_at(config.impact_fx, point, normal)
	queue_free()


# ── Montagem ─────────────────────────────────────────────────

func _setup_shape() -> void:
	_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "CollisionShape2D"
		add_child(_shape)
	var circle := CircleShape2D.new()  # um por instância
	circle.radius = config.radius
	_shape.shape = circle


func _setup_sprite() -> void:
	if config.sprite_frames == null:
		queue_redraw()  # placeholder em _draw()
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = config.sprite_frames
	add_child(_sprite)
	_play(config.charge_animation)


func _play(anim: StringName) -> void:
	if _sprite == null:
		return
	var frames := _sprite.sprite_frames
	var chosen := anim
	if not frames.has_animation(chosen):
		var names := frames.get_animation_names()
		if names.is_empty():
			return
		chosen = StringName(names[0])
	_sprite.play(chosen)


## Placeholder: só desenha quando não há SpriteFrames, para a bola ser visível antes da arte.
func _draw() -> void:
	if config and config.sprite_frames == null:
		draw_circle(Vector2.ZERO, config.radius, Color(1.0, 0.45, 0.1))
		draw_circle(Vector2.ZERO, config.radius * 0.5, Color(1.0, 0.85, 0.3))
