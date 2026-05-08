class_name StationaryFX
extends Node2D

var _def: StationaryParticleDef = null
var _sprite: AnimatedSprite2D   = null
var _current_level: int         = -1


func setup(def: StationaryParticleDef, facing_right: bool = true) -> void:
	_def = def

	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)

	if def.sprite_frames:
		_sprite.sprite_frames = def.sprite_frames

	z_index  = def.z_index
	scale    = def.base_scale
	position = def.offset

	_apply_facing(facing_right)
	visible = false  # começa escondido; set_level() o mostra


# ── API ──────────────────────────────────────────────────────

## Define qual animação mostrar baseado no nível (0, 1, 2...).
## level = -1 esconde o efeito.
func set_level(level: int, facing_right: bool = true) -> void:
	if not _def or not _sprite:
		return

	_current_level = level
	_apply_facing(facing_right)

	if level < 0 or level >= _def.level_animations.size():
		visible = false
		return

	var anim: String = _def.level_animations[level]
	if anim.is_empty():
		visible = false
		return

	visible = true
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim):
		if _sprite.animation != anim:
			_sprite.play(anim)

	# SFX por nível — tocado imediatamente ao mudar de nível.
	if _def.level_sfx.size() > level:
		var sfx: String = _def.level_sfx[level]
		if not sfx.is_empty():
			SoundManager.play_sfx(sfx)


func hide_fx() -> void:
	visible        = false
	_current_level = -1


func get_current_level() -> int:
	return _current_level


# ── Interno ──────────────────────────────────────────────────

func _apply_facing(facing_right: bool) -> void:
	if not _def or not _sprite:
		return
	if _def.flip_with_facing:
		_sprite.flip_h         = not facing_right
		position.x = abs(_def.offset.x) * (1 if facing_right else -1)
