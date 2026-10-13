# levels/common/MMX_Door.gd
extends Area2D

## Porta de entrada da arena do boss — FIX TEMPORÁRIO.
##
## PORTA DUPLA (estilo Mega Man clássico): sprite com 2 "postes"
## colados (32px total = 16+16, 48px altura cada).
##
## is_centered = false → câmera faz pan (esq/dir) ao entrar
## is_centered = true  → câmera trava no centro ao tocar o chão
##                       (ArenaFloorTrigger cuida disso)
##
## TODO — safeguard "entrar por cima sem porta" (porta no chão do chão):
##   Quando não há porta e o player cai direto na arena, essa lógica
##   de câmera não deve ativar. Resolver quando esse cenário for implementado.
##
## ESTRUTURA NO EDITOR:
##   MMX_Door (Area2D, raiz, este script)
##   ├── DoorLeft   (AnimatedSprite2D)
##   ├── DoorRight  (AnimatedSprite2D — mesma posição, mesmo SpriteFrames)
##   └── CollisionShape2D
##
## IMPORTANTE: Collision Mask deve incluir a layer física do Player.

enum DoorSide { LEFT, RIGHT }

@export var initial_side: DoorSide = DoorSide.LEFT
@export var forced_direction: Vector2 = Vector2.RIGHT
@export var forced_speed: float = 60.0
@export var open_animation: StringName = &"open"

## Quando true, a câmera NÃO faz pan ao entrar na porta —
## ela trava no centro da arena somente quando o player tocar o chão.
## Use para portas no meio do chão (player cai de cima).
@export var is_centered: bool = false

@onready var door_left:  AnimatedSprite2D = $DoorLeft
@onready var door_right: AnimatedSprite2D = $DoorRight

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if door_left.material:
		door_left.material = door_left.material.duplicate()
		door_left.material.set_shader_parameter("show_left_half", true)
	if door_right.material:
		door_right.material = door_right.material.duplicate()
		door_right.material.set_shader_parameter("show_left_half", false)

	_show_only(_initial_sprite(), _other_sprite())


func _initial_sprite() -> AnimatedSprite2D:
	return door_left if initial_side == DoorSide.LEFT else door_right


func _other_sprite() -> AnimatedSprite2D:
	return door_right if initial_side == DoorSide.LEFT else door_left


func _show_only(visible_sprite: AnimatedSprite2D, hidden_sprite: AnimatedSprite2D) -> void:
	visible_sprite.visible = true
	hidden_sprite.visible  = false


func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true

	# Registra na câmera qual behavior usar e em qual direção —
	# mas NÃO inicia o pan aqui. O pan (ou lock) só acontece
	# quando o player tocar o ArenaFloorTrigger.
	var cam := get_tree().get_first_node_in_group("GmCamera") as StablePixelCamera
	if cam:
		var pan_dir := Vector2.RIGHT if initial_side == DoorSide.LEFT else Vector2.LEFT
		cam.prepare_boss_intro(pan_dir, is_centered)

	GameManager.change_state(GameManager.GameState.ENTERING_ARENA)

	if body.has_method("enter_forced_movement"):
		body.enter_forced_movement(forced_direction, 0.0)

	_initial_sprite().play(open_animation)
	SoundManager.play_sfx("snd_dooropen")
	await _initial_sprite().animation_finished

	if is_instance_valid(body):
		body.set("forced_move_speed", forced_speed)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_show_only(_other_sprite(), _initial_sprite())
	_other_sprite().play(open_animation, -1.0, true)
	
	SoundManager.play_sfx("snd_bossdoorclose")

	if body.has_method("exit_forced_movement"):
		body.exit_forced_movement()
