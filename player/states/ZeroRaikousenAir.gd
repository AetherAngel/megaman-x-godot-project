# player/states/ZeroRaikousenAir.gd
extends State

# 28 frames @ 48fps = 0.583s
const DURATION: float = 0.583
const DASH_SPEED: float = 280.0

var elapsed: float = 0.0
var dash_dir: float = 1.0

func enter() -> void:
	elapsed = 0.0
	dash_dir = 1.0 if player.facing_right else -1.0
	player.change_animation_set("atk_raikousen_air")
	if player.sprite.sprite_frames.has_animation("atk_raikousen"):
		player.sprite.play("atk_raikousen")
	else:
		push_warning("⚠️ atk_raikousen_air não encontrada")
		player.state_machine.change_state("Fall")

func update(delta: float) -> void:
	elapsed += delta

	# Desloca na direção travada — não pode virar
	player.velocity.x = move_toward(player.velocity.x, dash_dir * DASH_SPEED, 800.0 * delta)

	# Fica no ar durante toda a animação
	player.set_vertical_speed(0.0)

	if not player.sprite.is_playing() or elapsed >= DURATION:
		player.state_machine.change_state("Fall")
