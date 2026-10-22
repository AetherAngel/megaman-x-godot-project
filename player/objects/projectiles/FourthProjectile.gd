# player/projectiles/FourthProjectile.gd
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float       = 600.0
var level: int         = 0
var is_alt: bool       = false   # false=main, true=alt(plasma)
var attacker: Node     = null    # quem disparou; atribuído pelo ChargeSystem antes do add_child

## Dano bruto de cada variante. Editável no Inspector.
## Valores iniciais de teste — o tipo de cada variante está em DAMAGE_TYPE_MAIN/PLASMA.
@export var damage_main: float   = 3.0
@export var damage_plasma: float = 3.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var _hit_component: HitComponent = get_node_or_null("HitComponent")

const SHOT_PATH = "res://resources/animations/spr_x_fourth_shot.tres"
const HIT_EFFECT_DURATION: float = 1.2

## Tipos de dano — chaves consultadas na resistance table do boss.
const DAMAGE_TYPE_MAIN: StringName   = DamageType.BUSTER_CHARGE_LV3
const DAMAGE_TYPE_PLASMA: StringName = DamageType.BUSTER_PLASMA

var _hit: bool = false


func _ready() -> void:
	add_to_group(&"projectile")  # limpo na vitória do boss (BossFlowManager)
		# Reduz o sprite pela metade
	sprite.scale = Vector2(0.5, 0.5)
	sprite.flip_h = direction.x < 0
	_setup_hit_component()

	if not ResourceLoader.exists(SHOT_PATH):
		push_warning("❌ FourthProjectile: " + SHOT_PATH + " não encontrado")
		return

	sprite.sprite_frames = load(SHOT_PATH)

	var anim = "shot_alt" if is_alt else "shot_main"
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		push_warning("⚠️ FourthProjectile: animação '" + anim + "' não encontrada")

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## Configura o HitComponent com o dano e o tipo da variante (main ou plasma).
func _setup_hit_component() -> void:
	if not _hit_component:
		push_warning("FourthProjectile: nó HitComponent não encontrado — este tiro não causará dano.")
		return

	_hit_component.damage         = damage_plasma if is_alt else damage_main
	_hit_component.damage_type_id = DAMAGE_TYPE_PLASMA if is_alt else DAMAGE_TYPE_MAIN
	_hit_component.attacker       = attacker


func _physics_process(delta: float) -> void:
	if _hit:
		return
	position += direction * speed * delta

	var screen = get_viewport().get_visible_rect()
	if not screen.has_point(get_global_transform_with_canvas().origin):
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	hit(body)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		return
	if area.is_in_group("player_hitbox"):
		return
	hit(null)


func hit(target = null) -> void:
	if _hit:
		return
	_hit  = true
	speed = 0.0

	set_deferred("monitoring", false)

	if is_alt:
		await _hit_alt(target)
	else:
		await _hit_main(target)


func _hit_main(target = null) -> void:
	# Notifica o HitBus; ele valida o alvo e encaminha ao take_damage() do HP.
	if target and _hit_component:
		_hit_component.report(target)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("hit_effect"):
		sprite.play("hit_effect")
		await sprite.animation_finished
	queue_free()


func _hit_alt(target = null) -> void:
	# Plasma — hit_effect_alt fica 1.2s no local

	# Hit único no impacto. O dano contínuo (abaixo) segue como TODO.
	if target and _hit_component:
		_hit_component.report(target)

	# TODO: damage overtime quando sistema de HP existir
	# if target and target.has_method("apply_damage_overtime"):
	#     target.apply_damage_overtime(dps, HIT_EFFECT_DURATION)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("hit_effect_alt"):
		sprite.play("hit_effect_alt")

	await get_tree().create_timer(HIT_EFFECT_DURATION).timeout
	queue_free()
