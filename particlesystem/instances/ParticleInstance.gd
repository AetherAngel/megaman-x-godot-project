class_name ParticleInstance
extends Node2D

var _def:      SpawnedParticleDef = null
var _velocity: Vector2            = Vector2.ZERO
var _lifetime: float              = 1.0
var _elapsed:  float              = 0.0
var _sprite:   AnimatedSprite2D   = null
var _owner:    Node2D             = null  # usado para follow_marker

# Follow (follow_marker): referência (marker ou pivô do dono) + deslocamento capturado no setup.
var _follow:            bool      = false
var _follow_has_marker: bool      = false
var _follow_marker:     Node2D    = null
var _follow_delta:      Vector2   = Vector2.ZERO  # em relação à referência, orientação NATIVA do dono


func setup(def: SpawnedParticleDef, direction: Vector2, speed: float, owner: Node2D = null) -> void:
	_def   = def
	_owner = owner
	_lifetime = maxf(0.05, def.lifetime + randf_range(-def.lifetime_variance, def.lifetime_variance))
	_velocity = direction * speed

	# Follow: guarda a referência e o deslocamento (que já inclui offset e position_variance).
	if def.follow_marker and owner != null and is_instance_valid(owner):
		_follow = true
		_follow_marker = ParticleFX.find_follow_marker(def, owner)
		_follow_has_marker = _follow_marker != null
		_follow_delta = ParticleFX.follow_delta_native(
			def, owner, ParticleFX.follow_reference(def, owner, _follow_marker), global_position)

	z_index  = def.z_index
	scale    = def.scale_start
	modulate = def.modulate_start

	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)

	# Rotação do sprite (padrão 0 = transform original). Só o sprite gira, não o nó.
	# sprite_rotation_degrees é ANTI-HORÁRIO; o rotation do Godot é horário — daí o sinal.
	var sprite_angle := -deg_to_rad(def.sprite_rotation_degrees)
	if def.rotate_to_direction and direction != Vector2.ZERO:
		sprite_angle += direction.angle()
	_sprite.rotation = sprite_angle

	if def.sprite_frames:
		_sprite.sprite_frames = def.sprite_frames
			# Espelha o sprite se inherit_facing estiver ativo
		if def.inherit_facing and owner and owner.get("facing_right") != null:
			_sprite.flip_h = not owner.facing_right
		if not def.animations.is_empty():
			var anim: String = def.animations[randi() % def.animations.size()]
			if _sprite.sprite_frames.has_animation(anim):
				_sprite.play(anim)


## Segue o dono: referência atual (marker ou pivô) + deslocamento capturado no setup, com o X
## espelhado pela orientação ATUAL (uma virada do dono vale no mesmo frame). Se o dono ou o
## marker forem liberados, para de seguir e o FX termina normalmente (fade e lifetime).
func _update_follow() -> void:
	if not _follow:
		return
	if not is_instance_valid(_owner) or (_follow_has_marker and not is_instance_valid(_follow_marker)):
		_follow = false
		return
	var reference := ParticleFX.follow_reference(_def, _owner, _follow_marker)
	global_position = ParticleFX.follow_point(_def, _owner, reference, _follow_delta)


## Substitui a vida sorteada no setup() por uma exata (ParticleFX.spawn_exact).
func set_lifetime(seconds: float) -> void:
	_lifetime = maxf(0.05, seconds)


func _process(delta: float) -> void:
	if not _def:
		queue_free()
		return

	_elapsed += delta
	var t := clampf(_elapsed / _lifetime, 0.0, 1.0)

	if t >= 1.0:
		queue_free()
		return

	# Movimento normal (só aplica se não está seguindo o dono)
	if _def.follow_marker:
		_update_follow()
	else:
		_velocity += _def.gravity * delta
		position  += _velocity * delta

	# Interpolações
	scale = _def.scale_start.lerp(_def.scale_end, t)

	if _def.fade_out:
		modulate = _def.modulate_start.lerp(_def.modulate_end, t)
