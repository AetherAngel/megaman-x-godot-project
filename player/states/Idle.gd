extends State

func enter() -> void:
	player.wall_slide_cancelled = false
	player.horizontal_momentum = 0
	if not player.get_meta("came_from_attack", false):
		player.combo_count = 0

func update(_delta: float) -> void:
	if not player.is_on_floor():
		player.state_machine.change_state("Fall")
		return
	var dir = InputManager.get_move_axis()
	if dir != 0:
		player.set_facing(dir > 0)
		player.state_machine.change_state("Run")
		player.set_horizontal_speed(1)
		return
	player.set_horizontal_speed(0)
	if InputManager.is_action_just_pressed("jump"):
		player.state_machine.change_state("Jump")
		return
	if InputManager.is_action_just_pressed("dash"):
		player.state_machine.change_state("Dash")
		return
	if player.current_character.default_weapon == "saber":
		if _check_techniques(player.current_armor.ground_techniques):
			return
	if InputManager.is_action_just_pressed("shoot") and GameManager.current_player == "Zero":
		player.combo_count = 1
		player.state_machine.change_state("SaberAttack")
		return
# X e Zero → ChargeSystem cuida do shoot em paralelo, sem state
