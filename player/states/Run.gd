# player/states/Run.gd
extends State

func enter() -> void:
	player.dash_jump_eligible    = false
	player.is_transitioning_walk = true
	player.last_state_was_dash   = false
	player.visual_library.play_state("Run")


func update(_delta: float) -> void:
	var dir := InputManager.get_move_axis()

	if not player.is_on_floor():
		player.state_machine.change_state("Fall")
		return

	# MMX: velocidade constante, sem rampa de aceleração.
	# Apertar a direção = full speed imediato.
	player.set_horizontal_speed(dir * player.speed * player.current_armor.dash_speed_multiplier)

	if dir != 0:
		player.set_facing(dir > 0)

	if dir == 0:
		player.state_machine.change_state("Idle")
		return

	if InputManager.is_action_just_pressed("jump"):
		player.state_machine.change_state("Jump")
		return

	if InputManager.is_action_just_pressed("dash"):
		player.state_machine.change_state("Dash")
		return

	if player.current_character.default_weapon == "saber":
		if _check_techniques(player.current_armor.ground_techniques):
			return
		if InputManager.is_action_just_pressed("shoot"):
			player.combo_count = 1
			player.state_machine.change_state("SaberAttack")
			return


func exit() -> void:
	player.is_transitioning_walk = false
