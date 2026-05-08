class_name DynamicFX
extends Node2D

var _def: DynamicParticleDef    = null
var _sprite: AnimatedSprite2D   = null
var _current_phase: int         = 0
var _phase_timer: float         = 0.0
var _spawn_velocity: Vector2    = Vector2.ZERO
var _gravity_accum: Vector2     = Vector2.ZERO


func setup(def: DynamicParticleDef, initial_velocity: Vector2 = Vector2.ZERO) -> void:
	_def            = def
	_spawn_velocity = initial_velocity
	_gravity_accum  = Vector2.ZERO

	z_index = def.z_index

	_sprite = AnimatedSprite2D.new()
	_sprite.animation_finished.connect(_on_animation_finished)
	add_child(_sprite)

	_enter_phase(0)


func _process(delta: float) -> void:
	if not _def:
		queue_free()
		return

	var phase := _get_phase(_current_phase)
	if not phase:
		queue_free()
		return

	# Acumula gravidade local da fase
	_gravity_accum += phase.gravity * delta

	# Velocidade: herda do spawn ou usa a da fase
	var base_vel := _spawn_velocity if phase.velocity_inherit_from_spawn else phase.velocity
	position += (base_vel + _gravity_accum) * delta

	# Timer da fase (só se duration > 0)
	if phase.duration > 0.0:
		_phase_timer += delta
		if _phase_timer >= phase.duration:
			_advance_phase()


# ── Fases ─────────────────────────────────────────────────────

func _enter_phase(index: int) -> void:
	if not _def or index >= _def.phases.size():
		queue_free()
		return

	_current_phase = index
	_phase_timer   = 0.0
	_gravity_accum = Vector2.ZERO

	var phase := _def.phases[index]

	# Só reseta velocidade se a fase não herda do spawn
	if not phase.velocity_inherit_from_spawn:
		_spawn_velocity = phase.velocity

	scale = phase.phase_scale

	if _sprite and phase.sprite_frames:
		_sprite.sprite_frames = phase.sprite_frames
		if phase.sprite_frames.has_animation(phase.animation):
			_sprite.play(phase.animation)


func _advance_phase() -> void:
	_enter_phase(_current_phase + 1)


func _on_animation_finished() -> void:
	var phase := _get_phase(_current_phase)
	if phase and phase.next_phase_on_anim_end and phase.duration <= 0.0:
		_advance_phase()


func _get_phase(index: int) -> DynamicPhase:
	if not _def or index < 0 or index >= _def.phases.size():
		return null
	return _def.phases[index]
