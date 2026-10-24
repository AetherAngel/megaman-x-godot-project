# systems/barrage/BarrageProjectile.gd
class_name BarrageProjectile
extends Area2D

## Projétil linear de uma saraivada (BarrageController). Anda em linha reta, gira a arte para
## apontar na direção do movimento e some ao tocar o player, o mundo (chão) ou ao fim da vida.
## O dano NÃO é daqui: vem do HitComponent filho (auto_report), configurado pelo spawner.
##
## Estrutura esperada da cena: Area2D (este script) → CollisionShape2D, Sprite (AnimatedSprite2D)
## e HitComponent. A rotação vale para a raiz inteira, então a hitbox gira junto com a arte.

## Segundos iniciais em que o contato com o MUNDO é ignorado. O projétil nasce acima da câmera
## e pode estar dentro de um teto; sem isso ele sumiria no mesmo instante.
@export var world_grace_time: float = 0.4

@onready var _sprite: AnimatedSprite2D = get_node_or_null("Sprite") as AnimatedSprite2D

var _velocity: Vector2 = Vector2.ZERO
var _life_left: float = 0.0
var _age: float = 0.0


func _ready() -> void:
	set_physics_process(false)  # só liga quando for disparado (fire)
	body_entered.connect(_on_body_entered)
	if _sprite and _sprite.sprite_frames:
		_sprite.play(_sprite.animation)


## Dispara o projétil. `lifetime` é um teto: normalmente o contato com o chão o remove antes.
func fire(direction: Vector2, speed: float, lifetime: float) -> void:
	var dir := direction.normalized()
	_velocity = dir * speed
	_life_left = lifetime
	_age = 0.0
	rotation = dir.angle() - _art_angle()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_age += delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


## Para onde a arte aponta COMO ESTÁ NA CENA, em radianos. A arte nativa dos SpriteFrames
## aponta para a DIREITA (0°); com flip_h ela aponta para a ESQUERDA (180°).
func _art_angle() -> float:
	return PI if (_sprite and _sprite.flip_h) else 0.0


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") or _age >= world_grace_time:
		queue_free()
