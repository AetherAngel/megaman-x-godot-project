extends State

var wall_direction: int = 0
var time_on_wall: float = 0.0
const MIN_WALL_TIME: float = 0.01
const ENTRY_GRACE: float = 0.01
const COOLDOWN_TIME: float = 0.01

func enter() -> void:
	if GameManager.current_player == "Zero":
		player.can_double_jump = true
	player.can_air_dash = true
	wall_direction = 1 if player.facing_right else -1
	time_on_wall = 0.0
	player.set_vertical_speed(0.0)
	print("=== ENTERED WALLSLIDE ===")

	# Jump bufferizado ao entrar → vai direto pro WallKick
	if InputManager.consume_jump_buffer():
		var away_dir = -wall_direction
		player.set_horizontal_speed(away_dir * 68.0)
		player.set_vertical_speed(player.jump_velocity * 0.93)
		player.set_facing(away_dir > 0)
		player.wall_slide_cancelled = true
		player.wall_slide_cooldown = COOLDOWN_TIME
		print(">>> JUMP BUFFER NO ENTER → WALLKICK <<<")
		player.state_machine.change_state("WallKick")
		player.force_wall_facing = false

func update(delta: float) -> void:
	time_on_wall += delta

	var pressing_into_wall = InputManager.is_action_pressed("move_right") if wall_direction == 1 else InputManager.is_action_pressed("move_left")

	# Bloqueio por cooldown
	if player.wall_slide_cooldown > 0.0:
		player.state_machine.change_state("Fall")
		print("→ BLOQUEADO por cooldown")
		return

	# Bloqueio só quando realmente está no chão
	if player.is_on_floor():
		player.wall_slide_cooldown = COOLDOWN_TIME
		player.state_machine.change_state("Fall")
		print("→ BLOQUEADO por estar no chão")
		player.force_wall_facing = false
		return

	if not pressing_into_wall:
		player.wall_slide_cancelled = true
		player.wall_slide_cooldown = COOLDOWN_TIME
		player.state_machine.change_state("Fall")
		print("→ Saindo por não pressionar parede")
		return

	# ESCORREGAMENTO
	player.set_vertical_speed(80.0)

	if time_on_wall < ENTRY_GRACE:
		return

	if time_on_wall < MIN_WALL_TIME:
		if not player.wall_ray.is_colliding():
			player.wall_slide_cooldown = COOLDOWN_TIME
			player.state_machine.change_state("Fall")
			return

	if not player.wall_ray.is_colliding():
		if time_on_wall > MIN_WALL_TIME + 0.15:
			player.wall_slide_cooldown = COOLDOWN_TIME
			player.state_machine.change_state("Fall")
			return
		player.set_vertical_speed(80.0)
		return

	# Jump
	if InputManager.consume_jump_buffer():
		print(">>> JUMP NO WALLSLIDE → WALLKICK <<<")
		var away_dir = -wall_direction
		player.set_horizontal_speed(away_dir * 68.0)
		player.set_vertical_speed(player.jump_velocity * 0.93)
		player.set_facing(away_dir > 0)
		player.wall_slide_cancelled = true
		player.wall_slide_cooldown = COOLDOWN_TIME
		player.state_machine.change_state("WallKick")
		return

	if InputManager.is_action_just_pressed("dash") and player.current_armor.has_air_dash and player.can_air_dash:
		player.state_machine.change_state("AirDash")
		return

	if _check_techniques(player.current_armor.wall_techniques):
		return
