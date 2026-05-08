# player/states/ZeroRaikousen.gd
extends State

# 27 frames @ 48fps = 0.5625s
const DURATION: float = 0.5625
const DASH_SPEED: float = 280.0

var elapsed: float = 0.0
var dash_dir: float = 1.0

func enter() -> void:
	elapsed = 0.0
	dash_dir = 1.0 if player.facing_right else -1.0
	player.change_animation_set("atk_raikousen")
	if player.sprite.sprite_frames.has_animation("atk_raikousen"):
		player.sprite.play("atk_raikousen")
	else:
		push_warning("⚠️ atk_raikousen não encontrada")
		player.state_machine.change_state("Idle")

func update(delta: float) -> void:
	elapsed += delta

	# Desloca suavemente na direção do facing
	player.velocity.x = move_toward(player.velocity.x, dash_dir * DASH_SPEED, 800.0 * delta)

	# Não pode cair mesmo passando por buracos
	if not player.is_on_floor():
		player.set_vertical_speed(0.0)

	if not player.sprite.is_playing() or elapsed >= DURATION:
		if player.is_on_floor():
			player.state_machine.change_state("Idle")
		else:
			player.state_machine.change_state("Fall")
