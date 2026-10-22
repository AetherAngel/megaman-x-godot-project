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

## Dano, tipo e attacker são configurados por Boss._spawn_object() a partir do
## SpawnableObject — este projétil só reporta o hit.
@onready var _hit_component: HitComponent = get_node_or_null("HitComponent")


func _ready() -> void:
	add_to_group(&"projectile")  # limpo na vitória do boss (BossFlowManager)
	if not _hit_component:
		push_warning("HadoukenProjectile: nó HitComponent não encontrado — este tiro não causará dano.")
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


func _on_hit(other: Node) -> void:
	# Notifica o HitBus; ele valida o alvo (descarta parede e o próprio boss)
	# e encaminha ao take_damage() do player.
	if _hit_component:
		_hit_component.report(other)
	queue_free()
