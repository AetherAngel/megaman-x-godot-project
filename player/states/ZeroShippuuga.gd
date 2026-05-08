# player/states/ZeroShippuuga.gd
extends State

# 14 frames @ 24fps = 0.583s
const DURATION: float = 0.583
const SLIDE_SPEED: float = 180.0
const SLIDE_START_FRAME: float = 0.375  # últimos ~5 frames

var elapsed: float = 0.0
var dash_dir: float = 1.0
var is_airborne: bool = false

func enter() -> void:
	elapsed = 0.0
	dash_dir = 1.0 if player.facing_right else -1.0
	is_airborne = not player.is_on_floor()
	player.change_animation_set("atk_shippuuga")
	if player.sprite.sprite_frames.has_animation("atk_shippuuga"):
		player.sprite.play("atk_shippuuga")
	else:
		push_warning("⚠️ atk_shippuuga não encontrada")
		player.state_machine.change_state("Idle")

func update(delta: float) -> void:
	elapsed += delta

	# Deslizamento nos últimos frames apenas se terrestre
	if not is_airborne and elapsed >= SLIDE_START_FRAME:
		player.velocity.x = move_toward(player.velocity.x, dash_dir * SLIDE_SPEED, 600.0 * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 800.0 * delta)

	# Se estava no ar e passa por buraco, fica no ar até terminar
	if is_airborne:
		player.set_vertical_speed(0.0)

	if not player.sprite.is_playing() or elapsed >= DURATION:
		if player.is_on_floor():
			player.state_machine.change_state("Idle")
		else:
			player.state_machine.change_state("Fall")
