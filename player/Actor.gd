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
# Fluxo por frame (definida em Actor):
#   1. _apply_gravity
#   2. _process_state           ← hook virtual (Player sobrescreve)
#   3. _process_physical_move   ← sequência física opcional (cutscene), no-op se nada ativo
#   4. _process_invulnerability
#   5. _process_movement        ← Character sobrescreve para pixel snap
#   6. _process_zero_health
#   7. _update_time_since_floor
# ============================================================

func _ready() -> void:
	current_health = max_health
	emitted_zero_health = false

func _physics_process(delta: float) -> void:
	if gravity_enabled:
		_apply_gravity(delta)
	_process_state(delta)
	_process_physical_move(delta)
	_process_invulnerability(delta)
	_process_movement(delta)
	_process_zero_health()
	_update_time_since_floor(delta)


func _process_state(_delta: float) -> void:
	pass  # virtual — sobrescrito pelo Player


# ── Gravidade ────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if velocity.y < 0.0:
		velocity.y += gravity * jump_gravity_multiplier * _physical_move_gravity_scale * delta
	else:
		velocity.y += gravity * fall_gravity_multiplier * _physical_move_gravity_scale * delta


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


## Versão base de take_damage — usada por inimigos simples sem HPSystem.
## Player e Boss sobrescrevem este método para rotear ao DamageHandler.
func take_damage(value: float, inflicter = null) -> void:
	if _is_invulnerable():
		return
	current_health -= value
	damaged.emit(value, inflicter)
	hp_changed.emit(current_health, max_health)  # ← PATCH: emite para inimigos simples
	if hit_effect:
		ParticleFX.spawn_at(hit_effect, global_position)


func has_health() -> bool:
	return current_health > 0.0


func _is_invulnerable() -> bool:
	return invulnerability > 0.0 or not toggleable_invulnerabilities.is_empty()


## Versão pública de _is_invulnerable(), para quem está de fora perguntar se um
## hit seria descartado agora (ex: HitComponent em modo CONTINUOUS).
## Só delega — a regra continua em um único lugar.
func is_invulnerable() -> bool:
	return _is_invulnerable()


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
# PHYSICAL MOVE — sequência física genérica (cutscene, ex: pulo de lava)
# Usa só as speed helpers/gravidade de cima — nenhuma física nova, só
# quem decide quando aplicar o quê. Nunca passa por
# BossAction/AttackPattern — ver PhysicalMoveDef/PhysicalMovePhase.
#
# Actor não sabe nada de visual (sem sprite/animação por nome aqui) —
# quem quiser reagir a uma troca de fase (tocar animação, FX, etc.)
# escuta physical_move_phase_entered e decide por conta própria.
# ============================================================

signal physical_move_finished
signal physical_move_phase_entered(phase: PhysicalMovePhase)

var _physical_move_def:   PhysicalMoveDef = null
var _physical_move_index: int             = 0
var _physical_move_timer: float           = 0.0
## Multiplica a gravidade normal (jump/fall_gravity_multiplier) durante
## uma sequência física. 1.0 = igual sempre foi (padrão, sem sequência
## ativa), 0.0 = suspensa, >1.0 = mais pesada que o normal (ex: arrasto
## na subida da lava, ainda subindo mas "pesadão").
var _physical_move_gravity_scale: float = 1.0
## True assim que a fase atual já esteve subindo de verdade — exigido
## antes de aceitar ExitOn.APEX, pra uma fase mal configurada (que já
## nasce com velocity.y >= 0) não sair no mesmíssimo frame sem se mover.
var _apex_was_rising: bool = false


## Inicia uma sequência de PhysicalMovePhase. Cancela qualquer sequência
## em andamento neste Actor. Emite physical_move_finished quando a
## última fase sair.
func start_physical_move(move_def: PhysicalMoveDef) -> void:
	if not move_def or move_def.phases.is_empty():
		return
	_physical_move_def = move_def
	_enter_physical_move_phase(0)


func stop_physical_move() -> void:
	_physical_move_def = null
	_physical_move_gravity_scale = 1.0


func is_doing_physical_move() -> bool:
	return _physical_move_def != null


func _process_physical_move(_delta: float) -> void:
	if not _physical_move_def:
		return

	var phase: PhysicalMovePhase = _physical_move_def.phases[_physical_move_index]
	_physical_move_timer += _delta

	if velocity.y < 0.0:
		_apex_was_rising = true

	# ── CONTINUOUS ─────────────────────────────────────────
	# Mantém a velocity da fase todo frame até ExitOn / stop.
	if phase.continuous and phase.set_velocity:
		velocity = _phase_velocity(phase, get_facing_flip())
	# ───────────────────────────────────────────────────────
	elif phase.hold_horizontal and phase.set_velocity:
		velocity.x = _phase_velocity(phase, get_facing_flip()).x

	if _physical_exit_reached(phase, _physical_move_timer, _apex_was_rising, velocity.y, is_on_floor()):
		_advance_physical_move()


## Condição de saída de uma fase — ponto ÚNICO, usado pelo movimento real e pela predição
## (predict_physical_move), para os dois nunca divergirem.
func _physical_exit_reached(phase: PhysicalMovePhase, timer: float, apex_rising: bool, vy: float, on_floor: bool) -> bool:
	match phase.exit:
		PhysicalMovePhase.ExitOn.TIMER:
			return timer >= phase.duration
		PhysicalMovePhase.ExitOn.APEX:
			return apex_rising and vy >= 0.0
		PhysicalMovePhase.ExitOn.LANDING:
			return on_floor
	return false


## Velocidade de uma fase, com o X espelhado se phase.mirror_with_facing (flip = +1 / -1).
func _phase_velocity(phase: PhysicalMovePhase, flip: int) -> Vector2:
	if phase.mirror_with_facing:
		return Vector2(phase.velocity.x * flip, phase.velocity.y)
	return phase.velocity


## +1 / -1: o quanto o visual está espelhado em relação à arte nativa. O padrão assume arte
## nativa virada para a DIREITA; quem tem outra convenção (ex: Boss) sobrescreve.
func get_facing_flip() -> int:
	return 1 if facing_right else -1


func _enter_physical_move_phase(index: int) -> void:
	print("[PM] t=%d enter idx=%d vel=%s" % [Time.get_ticks_msec(), _physical_move_index, velocity])
	_physical_move_index = index
	_physical_move_timer = 0.0
	_apex_was_rising = false
	var phase: PhysicalMovePhase = _physical_move_def.phases[index]

	_physical_move_gravity_scale = phase.gravity_scale
	if phase.set_velocity:
		velocity = _phase_velocity(phase, get_facing_flip())

	physical_move_phase_entered.emit(phase)


func _advance_physical_move() -> void:
	var next_index := _physical_move_index + 1
	if next_index >= _physical_move_def.phases.size():
		_physical_move_def = null
		_physical_move_gravity_scale = 1.0
		physical_move_finished.emit()
		return
	_enter_physical_move_phase(next_index)


## Simula, SEM mover o Actor, uma PhysicalMoveDef como ela rodaria agora: mesma gravidade
## (_apply_gravity), mesmas condições de saída (_physical_exit_reached), mesmo limite de queda
## e colisões do mundo via test_move. `flip` = fator de espelhamento do lado a testar.
## Depois que a sequência termina, continua em queda livre até pousar (como o jogo faria).
## Parede e teto fazem o corpo DESLIZAR pela superfície, como o move_and_slide do jogo — não
## abortam a simulação. Devolve: landed (pousou), floor_collider (o que está sob os pés ao
## pousar: é ele que diz se o pouso é bom), position (onde parou), time (s simulados) e
## blocked (informativo: encostou em parede/teto no caminho).
func predict_physical_move(move_def: PhysicalMoveDef, flip: int = 1, max_time: float = 4.0) -> Dictionary:
	var result := {"landed": false, "blocked": false, "position": global_position,
			"floor_collider": null, "time": 0.0}
	if not move_def or move_def.phases.is_empty():
		return result

	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var xf := global_transform
	var vel := Vector2.ZERO
	var index := 0
	var timer := 0.0
	var apex_rising := false
	var active := true
	var gscale: float = move_def.phases[0].gravity_scale
	var on_floor := is_on_floor()
	if move_def.phases[0].set_velocity:
		vel = _phase_velocity(move_def.phases[0], flip)
	var col := KinematicCollision2D.new()

	for _i in int(max_time / dt):
		result.time += dt
		# 1) gravidade (_apply_gravity)
		if gravity_enabled:
			vel.y += gravity * (jump_gravity_multiplier if vel.y < 0.0 else fall_gravity_multiplier) * gscale * dt
		# 2) fase (_process_physical_move)
		if active:
			var phase: PhysicalMovePhase = move_def.phases[index]
			timer += dt
			if vel.y < 0.0:
				apex_rising = true
			if phase.continuous and phase.set_velocity:
				vel = _phase_velocity(phase, flip)
			elif phase.hold_horizontal and phase.set_velocity:
				vel.x = _phase_velocity(phase, flip).x
			if _physical_exit_reached(phase, timer, apex_rising, vel.y, on_floor):
				index += 1
				if index >= move_def.phases.size():
					active = false
					gscale = 1.0
				else:
					phase = move_def.phases[index]
					timer = 0.0
					apex_rising = false
					gscale = phase.gravity_scale
					if phase.set_velocity:
						vel = _phase_velocity(phase, flip)

		# 3) movimento (_process_movement)
		vel.y = minf(vel.y, max_fall_speed)
		var motion := vel * dt
		if test_move(xf, motion, col):
			xf.origin += col.get_travel()
			var normal := col.get_normal()
			if normal.dot(up_direction) >= cos(floor_max_angle):
				result.landed = true
				result.floor_collider = col.get_collider()
				break
			result.blocked = true
			vel = vel.slide(normal)  # parede/teto: desliza e segue, como o jogo
		else:
			xf.origin += motion
		on_floor = false

	result.position = xf.origin
	return result


## O que está sob os pés (o collider do chão), ou null. Lê as colisões do último
## move_and_slide; sem nenhuma (ex: parado, só com floor snap), usa um raio curto para baixo.
## Para TileMapLayer o collider é o próprio nó da camada (dá para checar grupos nele).
func get_floor_collider() -> Object:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().dot(up_direction) >= cos(floor_max_angle):
			return c.get_collider()
	var from := global_position + Vector2(0.0, _feet_offset_y() - 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 6.0), collision_mask, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.get("collider") if not hit.is_empty() else null


## Distância do pivô até a base do primeiro CollisionShape2D retangular (px, para baixo).
func _feet_offset_y() -> float:
	for child in get_children():
		if child is CollisionShape2D and not (child as CollisionShape2D).disabled:
			var rect := (child as CollisionShape2D).shape as RectangleShape2D
			if rect:
				return (child as CollisionShape2D).position.y + rect.size.y * 0.5
	return 0.0


## Move suavemente até um destino exato, em `duration` segundos —
## ignora física durante o trajeto (chegada garantida, pra quando a
## cutscene precisa que o Actor pouse numa marca exata do cenário).
## Retorna o Tween — dá pra await tween.finished, ou conectar nele.
func move_to(destination: Vector2, duration: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "global_position", destination, duration)
	return tween


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
