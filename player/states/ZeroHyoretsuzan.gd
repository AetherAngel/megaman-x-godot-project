# player/states/ZeroHyouretsuzan.gd
extends State

func enter() -> void:
	player.change_animation_set("atk_hyouretsuzan")
	if player.sprite.sprite_frames.has_animation("atk_hyouretsuzan"):
		player.sprite.play("atk_hyouretsuzan")
	else:
		push_warning("⚠️ atk_hyouretsuzan não encontrada")
		player.state_machine.change_state("Fall")

func update(delta: float) -> void:
	# Ar control reduzido mas presente
	var dir = InputManager.get_move_axis()
	if dir != 0:
		player.velocity.x = move_toward(player.velocity.x, dir * player.speed * 0.4, player.air_acceleration * 0.2 * delta)

	# Deve sempre cair em direção ao chão
	if player.velocity.y < 0:
		player.velocity.y = 0.0

	# Tocou o chão — termina
	if player.is_on_floor():
		player.state_machine.change_state("Idle")
		return

	# Animação acabou mas ainda no ar — continua caindo
	if not player.sprite.is_playing():
		player.state_machine.change_state("Fall")
