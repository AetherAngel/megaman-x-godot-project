@tool
class_name TiledTextureRect
extends Node2D

enum Direction { UP, DOWN, LEFT, RIGHT }

@export var texture: Texture2D :
	set(v):
		texture = v
		call_deferred("_build")

@export var repeat_count: int = 3 :
	set(v):
		repeat_count = v
		call_deferred("_build")

@export var direction: Direction = Direction.DOWN :
	set(v):
		direction = v
		call_deferred("_build")

var _tiles: Array[TextureRect] = []


func _ready() -> void:
	_build()


func _build() -> void:
	if not is_inside_tree():
		return

	for tile in _tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	_tiles.clear()

	if not texture:
		return

	var tex_size := texture.get_size()

	for i in range(repeat_count):
		var rect := TextureRect.new()
		rect.texture             = texture
		rect.expand_mode         = TextureRect.EXPAND_KEEP_SIZE
		rect.stretch_mode        = TextureRect.STRETCH_KEEP
		rect.custom_minimum_size = tex_size

		var offset := Vector2.ZERO
		match direction:
			Direction.DOWN:  offset = Vector2(0,           round(tex_size.y) * i)
			Direction.UP:    offset = Vector2(0,          -round(tex_size.y) * i)
			Direction.RIGHT: offset = Vector2( round(tex_size.x) * i, 0)
			Direction.LEFT:  offset = Vector2(-round(tex_size.x) * i, 0)

		rect.position = offset
		add_child(rect)

		# No editor, mostra só o primeiro para posicionamento
		# Os demais só aparecem em runtime
		if Engine.is_editor_hint():
			rect.visible = (i == 0)
			rect.owner   = get_tree().edited_scene_root

		_tiles.append(rect)
