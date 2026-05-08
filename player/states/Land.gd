extends State

func enter() -> void:
	player.wall_slide_cooldown = 0.0
	player.wall_slide_cancelled = false
	player.change_animation_set("jump")
	player.can_double_jump = player.current_armor.has_double_jump
	ArmorManager.on_player_landed()

	# CORREÇÃO: damp_horizontal UMA VEZ na entrada, não todo frame no update.
	# Antes: update() chamava damp_horizontal(0.6) a cada frame →
	#        velocity.x *= 0.6^60 por segundo ≈ velocidade zerando em <0.5s instantaneamente.
	# Agora: frenagem acontece só ao tocar o chão, depois o update deixa a física fluir.
	player.damp_horizontal(0.1)

	if player.sprite.sprite_frames.has_animation("jumptoidle"):
		player.sprite.play("jumptoidle")
	elif player.sprite.sprite_frames.has_animation("land"):
		player.sprite.play("land")


func update(_delta: float) -> void:
	player.horizontal_momentum = 0
	player.can_air_dash = true

	var dir = InputManager.get_move_axis()

	if dir != 0:
		player.state_machine.change_state("Run")
	elif abs(player.velocity.x) < 1:
		player.state_machine.change_state("Idle")
