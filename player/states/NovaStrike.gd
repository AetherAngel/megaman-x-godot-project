# player/states/NovaStrike.gd
extends State

# ── Timings ──────────────────────────────────────────────────
const PREPARE_FRAMES: int   = 7       # frames de subida / pausa
const PREPARE_FPS:    float = 24.0
const STRIKE_SPEED:   float = 320.0   # velocidade do avanço
const STRIKE_DURATION: float = 0.45   # duração do avanço

var _prepare_elapsed: float = 0.0
var _strike_elapsed:  float = 0.0
var _phase: int = 0   # 0 = preparando, 1 = avançando
var _strike_dir: float = 1.0

const PREPARE_DURATION: float = PREPARE_FRAMES / PREPARE_FPS


func enter() -> void:
	_phase           = 0
	_prepare_elapsed = 0.0
	_strike_elapsed  = 0.0
	_strike_dir      = 1.0 if player.facing_right else -1.0

	player.set_horizontal_speed(0)
	player.set_vertical_speed(0.0)
	player.can_air_dash = false

	# Sinaliza ao ArmorManager que usou o Nova Strike
	ArmorManager.on_nova_strike_used()

	# Carrega animação de preparação
	player.change_animation_set("novastrike")
	if player.sprite.sprite_frames and player.sprite.sprite_frames.has_animation("PreparingAttack"):
		player.sprite.play("PreparingAttack")


func update(delta: float) -> void:
	match _phase:
		0:  # ── PREPARANDO ───────────────────────────────────
			_prepare_elapsed += delta
			# Sobe levemente durante a preparação
			player.set_vertical_speed(-30.0)
			player.set_horizontal_speed(0)

			if _prepare_elapsed >= PREPARE_DURATION:
				_phase = 1
				_strike_elapsed = 0.0
				player.set_vertical_speed(0.0)
				if player.sprite.sprite_frames and player.sprite.sprite_frames.has_animation("NovaStrike"):
					player.sprite.play("NovaStrike")

		1:  # ── AVANÇANDO ────────────────────────────────────
			_strike_elapsed += delta
			player.set_horizontal_speed(_strike_dir * STRIKE_SPEED)
			player.set_vertical_speed(0.0)

			if _strike_elapsed >= STRIKE_DURATION or not player.sprite.is_playing():
				player.state_machine.change_state("Fall")
				return

	if player.is_on_floor():
		player.state_machine.change_state("Land")


func exit() -> void:
	pass
