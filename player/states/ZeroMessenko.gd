# player/states/ZeroMessenko.gd
extends State

# 18 frames @ 24fps = 0.75s
const DURATION: float = 0.75

var elapsed: float = 0.0

func enter() -> void:
	elapsed = 0.0
	player.velocity.x = 0.0
	player.change_animation_set("messenko")
	if player.sprite.sprite_frames.has_animation("atk_messenko"):
		player.sprite.play("atk_messenko")
	else:
		push_warning("⚠️ atk_messenko não encontrada")
		player.state_machine.change_state("Idle")

func update(delta: float) -> void:
	elapsed += delta
	player.velocity.x = 0.0
	if not player.sprite.is_playing() or elapsed >= DURATION:
		player.state_machine.change_state("Idle")
