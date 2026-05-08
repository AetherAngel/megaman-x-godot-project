class_name ParticleInstance
extends Node2D

var _def:      SpawnedParticleDef = null
var _velocity: Vector2            = Vector2.ZERO
var _lifetime: float              = 1.0
var _elapsed:  float              = 0.0
var _sprite:   AnimatedSprite2D   = null
var _owner:    Node2D             = null  # usado para follow_marker


func setup(def: SpawnedParticleDef, direction: Vector2, speed: float, owner: Node2D = null) -> void:
	_def   = def
	_owner = owner
	_lifetime = maxf(0.05, def.lifetime + randf_range(-def.lifetime_variance, def.lifetime_variance))
	_velocity = direction * speed

	z_index  = def.z_index
	scale    = def.scale_start
	modulate = def.modulate_start

	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)

	if def.sprite_frames:
		_sprite.sprite_frames = def.sprite_frames
			# Espelha o sprite se inherit_facing estiver ativo
		if def.inherit_facing and owner and owner.get("facing_right") != null:
			_sprite.flip_h = not owner.facing_right
		if not def.animations.is_empty():
			var anim: String = def.animations[randi() % def.animations.size()]
			if _sprite.sprite_frames.has_animation(anim):
				_sprite.play(anim)


func _process(delta: float) -> void:
	if not _def:
		queue_free()
		return

	_elapsed += delta
	var t := clampf(_elapsed / _lifetime, 0.0, 1.0)

	if t >= 1.0:
		queue_free()
		return

	# follow_marker: atualiza a posição global a partir do marker do dono
	if _def.follow_marker and _owner and not _def.marker_path.is_empty():
		if not is_instance_valid(_owner):
			return
		var marker := _owner.get_node_or_null(NodePath(_def.marker_path))
		if marker is Node2D:
			global_position = (marker as Node2D).global_position

	# Movimento normal (só aplica se não está seguindo marker)
	if not _def.follow_marker:
		_velocity += _def.gravity * delta
		position  += _velocity * delta

	# Interpolações
	scale = _def.scale_start.lerp(_def.scale_end, t)

	if _def.fade_out:
		modulate = _def.modulate_start.lerp(_def.modulate_end, t)
