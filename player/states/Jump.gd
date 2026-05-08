extends State

@export var air_control: float = 0.75
var dash_buffer: float = 0.0
const DASH_BUFFER_TIME := 0.35

func enter() -> void:
	dash_buffer = 0.0

	if player.dash_jump_eligible and abs(player.horizontal_momentum) > 10.0:
		var hmspeed: float = player.horizontal_momentum * 0.75
		player.set_horizontal_speed(hmspeed) 
		player.dash_jump_eligible = false
	else:
		var dir = InputManager.get_move_axis()
		var dsotherdir: float = dir * player.speed * air_control
		player.set_horizontal_speed(dsotherdir)

	var jump_force = player.jump_velocity + player.current_armor.extra_jump_height
	player.set_vertical_speed(clamp(jump_force, -260, -150))

func update(delta: float) -> void:
	var dir = InputManager.get_move_axis()

	if dir != 0:
		var target = dir * player.speed * air_control
		player.accelerate_horizontal(target, player.air_acceleration * 0.25 ,delta)
		player.set_facing(dir > 0)

	# Reseta cancel quando pressiona de volta na direção da parede
	if player.wall_slide_cancelled and dir != 0:
		player.wall_slide_cancelled = false

	if InputManager.is_action_just_pressed("dash"):
		dash_buffer = DASH_BUFFER_TIME
	if dash_buffer > 0:
		dash_buffer -= delta
		if player.current_armor.has_air_dash and player.can_air_dash:
			player.state_machine.change_state("AirDash")
			return

	if InputManager.is_action_just_pressed("jump") and player.can_double_jump:
		player.can_double_jump = false
		if player.current_armor.has_double_jump and not GameManager.current_player == "Zero":
			player.set_vertical_speed(0.0)
			player.state_machine.change_state("Hover")
		else:
			player.set_vertical_speed(player.jump_velocity * 0.75)
			player.state_machine.change_state("Jump")
		return

	if player.current_character.default_weapon == "saber":
		if _check_techniques(player.current_armor.air_techniques):
			return
		if InputManager.is_action_just_pressed("shoot"):
			player.state_machine.change_state("SaberAttackAir")
			return
# X e Zero → ChargeSystem cuida do shoot em paralelo, sem state

# Nova Strike: → ↓ + Dash (ou ← ↓ + Dash)
	if ArmorManager.can_use_nova_strike():
		var forward = InputManager.is_action_pressed("move_right") if player.facing_right \
					  else InputManager.is_action_pressed("move_left")
		if forward and InputManager.is_action_pressed("move_down") \
		   and InputManager.is_action_just_pressed("dash"):
			player.state_machine.change_state("NovaStrike")
			return

	# WallSlide só se não foi cancelado voluntariamente
	if player.wall_ray.is_colliding() and player.velocity.y > 0 and player.wall_kick_grace <= 0.0:
		if player.current_armor.can_wall_kick and not player.wall_slide_cancelled:
			player.state_machine.change_state("WallSlide")
			return

	if player.velocity.y > 0:
		player.state_machine.change_state("Fall")
		return

	if player.is_on_floor():
		player.reset_momentum()
		player.state_machine.change_state("Land")
		return
