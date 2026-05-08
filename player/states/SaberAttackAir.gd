# player/states/SaberAttackAir.gd
extends State

const DURATION: float = 0.5  # 8 frames @ 16fps

var elapsed: float = 0.0

func enter() -> void:
	elapsed = 0.0
	player.change_animation_set("atk_jump")
	if player.sprite.sprite_frames.has_animation("atkjump"):
		player.sprite.play("atkjump")
	else:
		push_warning("⚠️ atkjump não encontrada")
		player.state_machine.change_state("Fall")

func update(delta: float) -> void:
	elapsed += delta
	# Mantém controle aéreo suave
	var dir = InputManager.get_move_axis()
	if dir != 0:
		player.velocity.x = move_toward(player.velocity.x, dir * player.speed * 0.8, player.air_acceleration * 0.3 * delta)
		player.set_facing(dir > 0)

	if player.is_on_floor():
		player.state_machine.change_state("ZeroLand")
		return

	if not player.sprite.is_playing() or elapsed >= DURATION:
		player.state_machine.change_state("Fall")
