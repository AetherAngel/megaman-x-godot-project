# player/states/ZeroMikazukizan.gd
extends State

# 8 frames @ 16fps = 0.5s
# Cancela queda temporariamente por alguns frames
const FLOAT_FRAMES: float = 0.2

var elapsed: float = 0.0

func enter() -> void:
	elapsed = 0.0
	player.change_animation_set("atk_mikazukizan")
	if player.sprite.sprite_frames.has_animation("atk_mikazukizan"):
		player.sprite.play("atk_mikazukizan")
	else:
		push_warning("⚠️ atk_mikazukizan não encontrada")
		player.state_machine.change_state("Fall")

func update(delta: float) -> void:
	elapsed += delta

	var dir = InputManager.get_move_axis()
	if dir != 0:
		player.velocity.x = move_toward(player.velocity.x, dir * player.speed * 0.8, player.air_acceleration * 0.3 * delta)
		player.set_facing(dir > 0)

	# Cancela gravidade nos primeiros frames
	if elapsed < FLOAT_FRAMES:
		player.set_vertical_speed(0.0)

	if player.is_on_floor():
		player.state_machine.change_state("Idle")
		return

	if not player.sprite.is_playing():
		player.state_machine.change_state("Fall")
