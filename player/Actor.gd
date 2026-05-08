class_name Actor
extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $Sprite

# ── Física ───────────────────────────────────────────────────
@export var ground_acceleration: float = 120.0
@export var max_fall_speed: float = 800.0
@export var speed: float = 180.0
@export var dash_speed: float = 360.0
@export var jump_velocity: float = -470.0
@export var gravity: float = 900.0
@export var air_control_multiplier: float = 0.35
@export var air_acceleration: float = 500.0
@export var jump_gravity_multiplier: float = 0.65
@export var fall_gravity_multiplier: float = 1.6

# ── Estado ───────────────────────────────────────────────────
var direction: Vector2         = Vector2.ZERO
var facing_right: bool         = true
var conveyor_belt_speed: float = 0.0
var time_since_on_floor: float = 0.0
var gravity_enabled: bool      = true

# ── Velocidades ──────────────────────────────────────────────
var bonus_velocity: Vector2 = Vector2.ZERO
var final_velocity: Vector2 = Vector2.ZERO

# ── Saúde ────────────────────────────────────────────────────
@export var max_health: float = 100.0
var current_health: float = 100.0
## Segundos de invulnerabilidade aplicados automaticamente ao tomar dano.
## 0 = sem invuln automática (Boss não usa — tem lógica própria).
@export var invuln_on_hit: float = 0.0

var invulnerability: float = 0.0
var toggleable_invulnerabilities: Array = []
var emitted_zero_health: bool = false

# ── FX ───────────────────────────────────────────────────────
@export_group("FX")
## Efeito spawnado na posição do Actor ao receber dano.
@export var hit_effect: SpawnedParticleDef
## Efeito spawnado na posição do Actor ao morrer (zero_health).
@export var death_effect: SpawnedParticleDef

# ── Sinais ───────────────────────────────────────────────────
signal damaged(value: float, inflicter)
signal zero_health
signal new_direction(dir: int)
signal hp_changed(current: float, maximum: float)


# ============================================================
# CORE — cadeia de física unificada
# Fluxo por frame:
#   1. _apply_gravity
#   2. _process_state      ← hook virtual (Player sobrescreve)
#   3. _process_invulnerability
#   4. _process_movement   ← Character sobrescreve para pixel snap
#   5. _process_zero_health
#   6. _update_time_since_floor
# ============================================================

func _ready() -> void:
	current_health = max_health
	emitted_zero_health = false

func _physics_process(delta: float) -> void:
	if gravity_enabled:
		_apply_gravity(delta)
	_process_state(delta)
	_process_invulnerability(delta)
	_process_movement(delta)
	_process_zero_health()
	_update_time_since_floor(delta)


func _process_state(_delta: float) -> void:
	pass  # virtual — sobrescrito pelo Player


# ── Gravidade ────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if velocity.y < 0.0:
		velocity.y += gravity * jump_gravity_multiplier * delta
	else:
		velocity.y += gravity * fall_gravity_multiplier * delta


# ── Movimento ────────────────────────────────────────────────

func _process_movement(delta: float) -> void:
	final_velocity = velocity

	if is_on_floor():
		final_velocity += bonus_velocity
	else:
		final_velocity.x += bonus_velocity.x
		final_velocity.x = move_toward(final_velocity.x, velocity.x, 600.0 * delta)

	if is_on_floor():
		final_velocity.x += conveyor_belt_speed

	final_velocity.y = minf(final_velocity.y, max_fall_speed)

	velocity = final_velocity
	move_and_slide()
	final_velocity = velocity


func _update_time_since_floor(delta: float) -> void:
	if is_on_floor():
		time_since_on_floor = 0.0
	else:
		time_since_on_floor += delta


# ── Saúde / Invulnerabilidade ─────────────────────────────────

func _process_zero_health() -> void:
	if not has_health() and not emitted_zero_health:
		emitted_zero_health = true
		if death_effect:
			ParticleFX.spawn_at(death_effect, global_position)
		zero_health.emit()


func take_damage(value: float, inflicter = null) -> void:
	if _is_invulnerable():
		return
	current_health -= value
	damaged.emit(value, inflicter)
	if hit_effect:
		ParticleFX.spawn_at(hit_effect, global_position)


func has_health() -> bool:
	return current_health > 0.0


func _is_invulnerable() -> bool:
	return invulnerability > 0.0 or not toggleable_invulnerabilities.is_empty()


func _process_invulnerability(delta: float) -> void:
	if invulnerability > 0.0:
		invulnerability -= delta


# ============================================================
# DIRECTION
# ============================================================

func set_direction(dir: int, update_facing: bool = false) -> void:
	direction.x = dir
	new_direction.emit(dir)
	if update_facing:
		if dir < 0:   facing_right = false
		elif dir > 0: facing_right = true


func get_facing_direction() -> int:
	return 1 if facing_right else -1


# ============================================================
# SPEED HELPERS — states chamam estas funções, nunca velocity diretamente
# ============================================================

func set_horizontal_speed(s: float) -> void:  velocity.x = s
func add_horizontal_speed(s: float) -> void:  velocity.x += s
func set_vertical_speed(s: float) -> void:    velocity.y = s
func add_vertical_speed(s: float) -> void:    velocity.y += s

func damp_horizontal(factor: float) -> void:
	velocity.x *= factor

func lerp_stop_horizontal(factor: float, delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, factor * delta)

func accelerate_horizontal(target: float, accel: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, target, accel * delta)

func clamp_horizontal(max_speed: float) -> void:
	velocity.x = clamp(velocity.x, -max_speed, max_speed)

func nudge_x(amount: float) -> void:
	move_and_collide(Vector2(amount, 0.0))


# ============================================================
# CONVEYOR
# ============================================================

func add_conveyor_belt_speed(s: float) -> void:    conveyor_belt_speed += s
func reduce_conveyor_belt_speed(s: float) -> void: conveyor_belt_speed -= s


# ============================================================
# STOP
# ============================================================

func stop_all_movement() -> void:
	velocity       = Vector2.ZERO
	bonus_velocity = Vector2.ZERO
	final_velocity = Vector2.ZERO


func destroy() -> void:
	queue_free()
