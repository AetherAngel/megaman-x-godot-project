# player/projectiles/FourthProjectile.gd
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float       = 600.0
var level: int         = 0
var is_alt: bool       = false   # false=main, true=alt(plasma)

@onready var sprite: AnimatedSprite2D = $Sprite

const SHOT_PATH = "res://resources/animations/spr_x_fourth_shot.tres"
const HIT_EFFECT_DURATION: float = 1.2

var _hit: bool = false


func _ready() -> void:
		# Reduz o sprite pela metade
	sprite.scale = Vector2(0.5, 0.5)
	sprite.flip_h = direction.x < 0

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
	# TODO: aplicar dano ao target quando sistema de HP existir
	# if target and target.has_method("take_damage"):
	#     target.take_damage(damage_value)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("hit_effect"):
		sprite.play("hit_effect")
		await sprite.animation_finished
	queue_free()


func _hit_alt(target = null) -> void:
	# Plasma — hit_effect_alt fica 1.2s no local

	# TODO: damage overtime quando sistema de HP existir
	# if target and target.has_method("apply_damage_overtime"):
	#     target.apply_damage_overtime(dps, HIT_EFFECT_DURATION)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("hit_effect_alt"):
		sprite.play("hit_effect_alt")

	await get_tree().create_timer(HIT_EFFECT_DURATION).timeout
	queue_free()
