# player/states/ZeroWallAttack.gd
extends State

# 10 frames @ 24fps = 0.416s
const DURATION: float = 0.416

var elapsed: float = 0.0

func enter() -> void:
	elapsed = 0.0
	player.change_animation_set("atk_wall")
	if player.sprite.sprite_frames.has_animation("atk_wall"):
		player.sprite.play("atk_wall")
	else:
		push_warning("⚠️ atk_wall não encontrada")
		player.state_machine.change_state("Fall")

func update(delta: float) -> void:
	elapsed += delta
	# Mantém deslizando na parede durante o ataque
	player.velocity.y = move_toward(player.velocity.y, 80.0, 60.0 * delta)

	if player.is_on_floor():
		player.state_machine.change_state("Idle")
		return

	if not player.sprite.is_playing() or elapsed >= DURATION:
		player.state_machine.change_state("WallSlide")
