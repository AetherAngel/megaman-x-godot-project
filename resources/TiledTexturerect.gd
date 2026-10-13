@tool
class_name TiledSpriteFrames
extends Node2D

enum Direction { UP, DOWN, LEFT, RIGHT }

@export var sprite_frames: SpriteFrames :
	set(v):
		sprite_frames = v
		call_deferred("_build")

@export var animation: StringName = &"" :
	set(v):
		animation = v
		call_deferred("_build")

@export var repeat_count: int = 3 :
	set(v):
		repeat_count = max(1, v)
		call_deferred("_build")

@export var direction: Direction = Direction.DOWN :
	set(v):
		direction = v
		call_deferred("_build")

@export var autoplay: bool = true :
	set(v):
		autoplay = v
		call_deferred("_build")

var _tiles: Array[AnimatedSprite2D] = []


func _ready() -> void:
	_build()


func _build() -> void:
	if not is_inside_tree():
		return

	# Limpa tiles antigos
	for tile in _tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	_tiles.clear()

	if not sprite_frames:
		return

	# Pega a animação (ou a primeira disponível)
	var anim := animation
	if anim == &"" or not sprite_frames.has_animation(anim):
		var anims := sprite_frames.get_animation_names()
		if anims.is_empty():
			return
		anim = anims[0]

	var frame_count := sprite_frames.get_frame_count(anim)
	if frame_count == 0:
		return

	var tex := sprite_frames.get_frame_texture(anim, 0)
	if not tex:
		return

	var tex_size := tex.get_size()

	for i in range(repeat_count):
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = sprite_frames
		sprite.animation = anim
		sprite.centered = false

		# Forma mais confiável de fazer autoplay
		if autoplay:
			sprite.autoplay = anim          # ← essa é a chave
		else:
			sprite.autoplay = &""

		var offset := Vector2.ZERO
		match direction:
			Direction.DOWN:
				offset = Vector2(0, round(tex_size.y) * i)
			Direction.UP:
				offset = Vector2(0, -round(tex_size.y) * i)
			Direction.RIGHT:
				offset = Vector2(round(tex_size.x) * i, 0)
			Direction.LEFT:
				offset = Vector2(-round(tex_size.x) * i, 0)

		sprite.position = offset
		add_child(sprite)

		# Força play depois de adicionar (ajuda bastante no editor e em rebuilds)
		if autoplay:
			sprite.play()

		# No editor mostra só o primeiro tile
		if Engine.is_editor_hint():
			sprite.visible = (i == 0)
			sprite.owner = get_tree().edited_scene_root

		_tiles.append(sprite)
