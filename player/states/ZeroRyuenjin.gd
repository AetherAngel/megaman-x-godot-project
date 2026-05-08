# player/states/ZeroRyuenjin.gd
extends State

# 17 frames @ 24fps = 0.708s
const DURATION: float = 0.708
const RISE_SPEED: float = -220.0

var elapsed: float = 0.0

func enter() -> void:
	elapsed = 0.0
	player.change_animation_set("atk_ryuenjin")
	if player.sprite.sprite_frames.has_animation("atk_ryuenjin"):
		player.sprite.play("atk_ryuenjin")
		player.set_vertical_speed(RISE_SPEED)
		player.velocity.x = 0.0
	else:
		push_warning("⚠️ atk_ryuenjin não encontrada")
		player.state_machine.change_state("Idle")

func update(delta: float) -> void:
	elapsed += delta
	# Sem controle horizontal durante o uppercut
	player.velocity.x = 0.0

	if not player.sprite.is_playing() or elapsed >= DURATION:
		player.state_machine.change_state("Fall")
