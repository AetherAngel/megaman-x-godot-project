extends State

# Friction aplicada quando sem input no ar — faz o momentum do dash decair.
# MMX: soltar a direção no ar deve desacelerar suavemente até parar.
const AIR_FRICTION_ACCEL := 260.0

func enter() -> void:
	print("falling")

func update(delta: float) -> void:
	var dir = InputManager.get_move_axis()

	# Reseta cancel ao pressionar direção
	if player.wall_slide_cancelled and dir != 0:
		player.wall_slide_cancelled = false

	# ==================== WALLSLIDE CHECK ====================
	if player.wall_ray.is_colliding() and not player.is_on_floor() \
			and player.velocity.y > 0 and player.wall_kick_grace <= 0.0:
		var pressing_into_wall := InputManager.is_action_pressed("move_right") \
				if player.facing_right else InputManager.is_action_pressed("move_left")
		if pressing_into_wall and player.current_armor.can_wall_kick \
				and not player.wall_slide_cancelled and player.wall_slide_cooldown <= 0.0:
			player.state_machine.change_state("WallSlide")
			return

	# ==================== CONTROLE HORIZONTAL NO AR ====================
	if dir != 0:
		# CORREÇÃO: target primeiro, depois accel, depois delta — sem pré-multiplicar delta.
		# Antes: accelerate_horizontal(velocity.x, target, air_acceleration * delta)
		#        → move_toward(velocity.x, velocity.x, target * air_acceleration * delta²) = nada.
		var target: float = dir * player.speed * player.air_control_multiplier
		player.accelerate_horizontal(target, player.air_acceleration, delta)
		player.set_facing(dir > 0)
	else:
		# Sem input: decai o momentum (dash-jump, etc.) gradualmente em direção a zero.
		# Parar de pressionar a direção desacelera no ar — soltar o controle freia.
		player.accelerate_horizontal(0.0, AIR_FRICTION_ACCEL, delta)

	# ==================== INPUTS ====================
	if InputManager.is_action_just_pressed("jump") and player.can_double_jump:
		player.can_double_jump = false
		if player.current_armor.has_double_jump and not GameManager.current_player == "Zero":
			player.set_vertical_speed(0.0)
			player.state_machine.change_state("Hover")
		else:
			player.set_vertical_speed(player.jump_velocity * 0.75)
			player.state_machine.change_state("Jump")
		return

	if ArmorManager.can_use_nova_strike():
		var forward := InputManager.is_action_pressed("move_right") if player.facing_right \
				else InputManager.is_action_pressed("move_left")
		if forward and InputManager.is_action_pressed("move_down") \
				and InputManager.is_action_just_pressed("dash"):
			player.state_machine.change_state("NovaStrike")
			return

	if InputManager.is_action_just_pressed("dash"):
		if player.current_armor.has_air_dash and player.can_air_dash:
			player.state_machine.change_state("AirDash")
			return

	if player.current_character.default_weapon == "saber":
		if _check_techniques(player.current_armor.ground_techniques):
			return
		if InputManager.is_action_just_pressed("shoot"):
			player.combo_count = 1
			player.state_machine.change_state("SaberAttack")
			return

	if player.is_on_floor():
		player.wall_slide_cooldown = 0.0
		player.reset_momentum()
		player.state_machine.change_state("Land")
