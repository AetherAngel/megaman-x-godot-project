extends State

var wall_direction: int = 0
var kick_time: float = 0.0
var kick_dir: int = 0
var face_dir: int = 1
var last_input_dir: float = 0.0
var return_buffer_time: float = 0.0

const KICK_LOCK_TIME     := 0.08
const KICK_CURVE_FORCE   := 160.0
const KICK_AWAY_FORCE    := 5.0   # corrigido typo: FOCE → FORCE
const KICK_UP_HOLD_TIME  := 0.15
const KICK_ANIM_MIN_TIME := 0.15
const RETURN_BUFFER_MAX  := 0.066

var did_freeze_anim: bool = false
var did_freeze: bool = false


func enter() -> void:
	did_freeze_anim = false
	did_freeze      = false
	kick_time       = 0.0
	last_input_dir  = 0.0
	return_buffer_time = 0.0

	player.wall_slide_cancelled = true
	player.wall_kick_grace = 0.02

	if player.wall_ray.is_colliding():
		var normal := player.wall_ray.get_collision_normal()
		wall_direction = -1 if normal.x > -1 else 1  # lógica da curva, não mexer
		face_dir = 0 if normal.x > 1 else -1         # facing independente
	else:
		wall_direction = 1 if player.facing_right else -1
		face_dir = -wall_direction

	kick_dir = -wall_direction
	player.set_facing(wall_direction > 0)

	var push_back := 105.0 if GameManager.current_player == "Zero" else 90.0

	# Usa helpers do Actor — sem tocar velocity diretamente.
	player.set_horizontal_speed(kick_dir * push_back)
	player.set_vertical_speed(-172.0)

	# nudge_x usa move_and_collide, então paredes bloqueiam o deslocamento.
	# Antes: player.position.x += kick_dir * KICK_AWAY_FOCE (bypassa física)
	player.nudge_x(kick_dir * KICK_AWAY_FORCE)


func update(delta: float) -> void:
	kick_time += delta

	var dir                 := InputManager.get_move_axis()
	var return_dir          := -kick_dir
	var is_pressing_return  := dir == return_dir
	var was_pressing_return := last_input_dir == return_dir
	var is_moving_away: int   = sign(player.velocity.x) == kick_dir
	var is_moving_toward_wall: int = sign(player.velocity.x) == return_dir

	# Segura subida — compensa a gravidade aplicada pelo Actor nesse frame.
	if kick_time < KICK_UP_HOLD_TIME:
		var grav := _get_gravity_compensation()
		# add_vertical_speed em vez de velocity.y -= ...
		player.add_vertical_speed(-grav * delta * 0.85)

	# Fase 1 — lock imediato sem input.
	if kick_time < KICK_LOCK_TIME:
		pass
	else:
		# Sem input → FALL só após animação terminar.
		if dir == 0:
			if kick_time >= KICK_ANIM_MIN_TIME:
				if not player.sprite.is_playing() or player.sprite.animation != "wallkick":
					player.state_machine.change_state("Fall")
					return

		# Buffer de input estilo X6.
		if is_pressing_return:
			return_buffer_time = RETURN_BUFFER_MAX
			player.set_facing(return_dir > 0)
		else:
			return_buffer_time = max(0.0, return_buffer_time - delta)

		var has_return_intent := is_pressing_return or return_buffer_time > 0.0

		# Trocou direção no meio → FALL.
		if was_pressing_return and dir != return_dir:
			player.state_machine.change_state("Fall")
			return

		# Indo para longe sem intenção de voltar → FALL após animação.
		if not has_return_intent and is_moving_away and dir != 0:
			if not player.sprite.is_playing() or player.sprite.animation != "wallkick":
				player.state_machine.change_state("Fall")
				return

		# Curva de retorno — só com intenção.
		if has_return_intent:
			# add + accelerate em vez de velocity.x += ... / move_toward(velocity.x, ...)
			player.add_horizontal_speed(return_dir * KICK_CURVE_FORCE * delta)
			player.accelerate_horizontal(return_dir * player.speed, 1200.0, delta)

		# Freeze (timing exato do wall kick).
		if has_return_intent and is_moving_away:
			did_freeze = true
			if abs(player.velocity.y) < 25.0 and kick_time < 0.20:
				var grav := _get_gravity_compensation()
				player.add_vertical_speed(-grav * delta)
				player.set_vertical_speed(0.0)
				player.set_facing(wall_direction == 1)

		# jumpintohigh — só após o freeze.
		if has_return_intent and not is_moving_away and not did_freeze_anim:
			if did_freeze:
				did_freeze_anim = true

		# Perdeu timing → FALL.
		if has_return_intent and not is_moving_away:
			if not is_moving_toward_wall:
				if did_freeze_anim and player.sprite.is_playing():
					pass
				else:
					player.state_machine.change_state("Fall")
					return

		# Cap de velocidade — usa clamp_horizontal em vez de velocity.x = clamp(...)
		player.clamp_horizontal(player.speed * 0.95)

	# Transições padrão.
	if player.velocity.y > 0:
		if did_freeze_anim and player.sprite.is_playing():
			pass
		else:
			player.state_machine.change_state("Fall")
			return

	if player.is_on_floor():
		player.reset_momentum()
		player.state_machine.change_state("Land")
		return

	if player.wall_ray.is_colliding() and player.velocity.y > 0 and player.wall_kick_grace <= 0.0:
		if player.current_armor.can_wall_kick and not player.wall_slide_cancelled:
			player.state_machine.change_state("WallSlide")

	last_input_dir = dir


func _get_gravity_compensation() -> float:
	if player.velocity.y < 0.0:
		return player.gravity * player.jump_gravity_multiplier
	else:
		return player.gravity * player.fall_gravity_multiplier
