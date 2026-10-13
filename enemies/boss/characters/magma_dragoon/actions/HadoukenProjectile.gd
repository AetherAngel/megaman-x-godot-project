# enemies/boss/characters/magma_dragoon/projectiles/HadoukenProjectile.gd
class_name HadoukenProjectile
extends Area2D

## Bola de fogo do Hadouken. Reta, sem gravidade, sem perseguição —
## atinge o player ou a parede e desaparece.
##
## Lifetime NÃO é controlado aqui — Boss._spawn_object() já despawna a
## instância via timer, lido de SpawnableObject.lifetime. Duplicar essa
## lógica aqui criaria duas fontes de verdade pro mesmo despawn.

@export var speed: float = 220.0

var _direction: int = 1  # 1 = direita, -1 = esquerda — setado por launch()


func _ready() -> void:
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)


## Chamado por Boss._spawn_object() logo após instanciar — define a
## direção "pra frente" com base em pra onde o boss estava olhando
## no momento do lançamento.
func launch(direction: int) -> void:
	_direction = direction
	scale.x = direction  # espelha o sprite pro lado certo


func _physics_process(delta: float) -> void:
	position.x += _direction * speed * delta


func _on_hit(_other: Node) -> void:
	# TODO: aplicar dano via SpawnableObject.damage/damage_tag quando o
	# sistema de hitbox existir. Por enquanto só desaparece ao tocar
	# player ou parede — sem sistema de dano ainda.
	queue_free()
