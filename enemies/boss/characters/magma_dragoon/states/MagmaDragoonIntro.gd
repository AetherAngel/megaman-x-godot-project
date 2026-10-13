# enemies/boss/magma_dragoon/states/MagmaDragoonIntro.gd
extends Node

## Primeira "vida" do Magma Dragoon — toca a animação de entrada e,
## ao terminar, libera o BTRunner pra ele começar a agir.
##
## NÃO extends State/StateBase — aquela classe tem "var player: Player"
## tipado especificamente pra Player. Boss usa a propriedade NATIVA
## "owner" (todo Node já tem isso), setada pelo StateMachine via
## child.set("owner", _host). Ver StateMachine._register_states().
##
## NÃO depende do auto-visual do StateMachine (visual_library.play_state
## usaria o NOME DO STATE como nome de animação — "Intro" não existe
## no spr_magma_dragoon.tres, a animação real é "magma_dragoon_intro").
## Por isso chamamos boss.set_visual_state() diretamente aqui.

var _boss: Boss
var _finished: bool = false


func enter() -> void:
	_boss = owner as Boss
	if not _boss:
		push_error("[MagmaDragoonIntro] owner não é um Boss.")
		return

	_finished = false
	_boss.set_visual_state(&"magma_dragoon_intro")


func update(_delta: float) -> void:
	if not _boss or _finished:
		return

	# Animação sem loop — quando o AnimatedSprite2D para de tocar,
	# a intro terminou.
	
	var sprite_node := _boss.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite_node and not sprite_node.is_playing():
		_finish_intro()
		print ("intro finalizada")


func exit() -> void:
	pass


func _finish_intro() -> void:
	_finished = true
	# Libera o BTRunner — a partir daqui o boss decide e age por conta própria.
	# NÃO transiciona pra outro state — StateMachine do Boss só tem
	# Intro e Death. O que acontece "no meio" é responsabilidade do
	# BTRunner/BossAction (Parte 4), não de um state "Idle" aqui.
	_boss.on_intro_finished()
