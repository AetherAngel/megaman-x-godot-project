# player/states/ZeroDenjin.gd
extends State

# 8 frames @ 16fps = 0.5s
const DURATION: float = 0.5
const RISE_SPEED: float = -180.0

var elapsed: float = 0.0

func enter() -> void:
	elapsed = 0.0
	player.change_animation_set("atk_denjin")
	if player.sprite.sprite_frames.has_animation("atk_denjin"):
		player.sprite.play("atk_denjin")
		player.velocity.y = RISE_SPEED
		player.velocity.x = 0.0
	else:
		push_warning("⚠️ atk_denjin não encontrada")
		player.state_machine.change_state("Idle")

func update(delta: float) -> void:
	elapsed += delta
	player.velocity.x = 0.0

	if not player.sprite.is_playing() or elapsed >= DURATION:
		player.state_machine.change_state("Fall")
