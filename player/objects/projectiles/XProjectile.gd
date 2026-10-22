# player/projectiles/XProjectile.gd
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float       = 600.0
var level: int         = 0    # 0=lv1, 1=lv2, 2=lv3
var is_alt: bool       = false
var attacker: Node     = null  # quem disparou; atribuído pelo ChargeSystem antes do add_child

## Dano bruto por nível de carga (0=lv1, 1=lv2, 2=lv3). Editável no Inspector.
## Valores iniciais de teste — o tipo de cada nível está em DAMAGE_TYPE_BY_LEVEL.
@export var damage_by_level: Array[float] = [1.0, 2.0, 3.0]

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var _hit_component: HitComponent = get_node_or_null("HitComponent")

const ANIM_PATHS: Array[String] = [
	"res://resources/animations/spr_x_shot_lv1.tres",
	"res://resources/animations/spr_x_shot_lv2.tres",
	"res://resources/animations/spr_x_shot_lv3.tres",
]

## Tipo de dano de cada nível — chave consultada na resistance table do boss.
const DAMAGE_TYPE_BY_LEVEL: Array[StringName] = [
	DamageType.BUSTER,
	DamageType.BUSTER_CHARGE_LV2,
	DamageType.BUSTER_CHARGE_LV3,
]

var _hit: bool = false


func _ready() -> void:
	add_to_group(&"projectile")  # limpo na vitória do boss (BossFlowManager)
	sprite.flip_h = direction.x < 0
	_setup_hit_component()

	var path = ANIM_PATHS[clamp(level, 0, 2)]
	if ResourceLoader.exists(path):
		sprite.sprite_frames = load(path)
		if sprite.sprite_frames.has_animation("main_shot"):
			sprite.play("main_shot")
	else:
		push_warning("❌ XProjectile: animação não encontrada: " + path)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## Configura o HitComponent com o dano e o tipo do nível atual.
func _setup_hit_component() -> void:
	if not _hit_component:
		push_warning("XProjectile: nó HitComponent não encontrado — este tiro não causará dano.")
		return

	var idx := clampi(level, 0, DAMAGE_TYPE_BY_LEVEL.size() - 1)
	_hit_component.damage         = damage_by_level[idx] if idx < damage_by_level.size() else 0.0
	_hit_component.damage_type_id = DAMAGE_TYPE_BY_LEVEL[idx]
	_hit_component.attacker       = attacker


func _physics_process(delta: float) -> void:
	if _hit:
		return
	position += direction * speed * delta

	# Remove ao sair da tela
	var screen = get_viewport().get_visible_rect()
	if not screen.has_point(get_global_transform_with_canvas().origin):
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	hit(body)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		return
	hit(null)


func hit(target = null) -> void:
	if _hit:
		return
	_hit  = true
	speed = 0.0

	# Notifica o HitBus; ele valida o alvo e encaminha ao take_damage() do HP.
	if target and _hit_component:
		_hit_component.report(target)

	set_deferred("monitoring", false)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("hit_effect"):
		sprite.play("hit_effect")
		await sprite.animation_finished
	queue_free()
