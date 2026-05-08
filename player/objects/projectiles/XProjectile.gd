# player/projectiles/XProjectile.gd
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float       = 600.0
var level: int         = 0    # 0=lv1, 1=lv2, 2=lv3
var is_alt: bool       = false

@onready var sprite: AnimatedSprite2D = $Sprite

const ANIM_PATHS: Array[String] = [
	"res://resources/animations/spr_x_shot_lv1.tres",
	"res://resources/animations/spr_x_shot_lv2.tres",
	"res://resources/animations/spr_x_shot_lv3.tres",
]

var _hit: bool = false


func _ready() -> void:
	sprite.flip_h = direction.x < 0

	var path = ANIM_PATHS[clamp(level, 0, 2)]
	if ResourceLoader.exists(path):
		sprite.sprite_frames = load(path)
		if sprite.sprite_frames.has_animation("main_shot"):
			sprite.play("main_shot")
	else:
		push_warning("❌ XProjectile: animação não encontrada: " + path)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


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

	# TODO: aplicar dano ao target quando sistema de HP existir
	# if target and target.has_method("take_damage"):
	#     target.take_damage(damage_value)

	set_deferred("monitoring", false)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("hit_effect"):
		sprite.play("hit_effect")
		await sprite.animation_finished
	queue_free()
