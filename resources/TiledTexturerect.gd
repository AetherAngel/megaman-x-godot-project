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

## CollisionShape2D a ser replicado junto com os sprites (opcional).
## Arraste o nó da árvore para este campo.
## Se ficar vazio, procura UM ÚNICO CollisionShape2D entre os irmãos (filhos do
## mesmo pai) e entre os filhos deste nó. Se achar mais de um, avisa no Output
## e não replica nada — nesse caso, selecione o nó aqui.
## O nó original continua sendo o tile 0; as cópias (tiles 1..N-1) são criadas
## no mesmo pai do original, deslocadas pela mesma distância dos sprites.
@export var collision_shape: CollisionShape2D :
	set(v):
		collision_shape = v
		call_deferred("_build")

## Marca as cópias de colisão geradas por este nó (valor = id da instância dona),
## para nunca confundi-las com o CollisionShape2D original nem com as de outro nó.
const COPY_META := &"_tiled_collision_copy"

var _tiles: Array[AnimatedSprite2D] = []
var _collision_copies: Array[CollisionShape2D] = []


func _ready() -> void:
	_build()


func _exit_tree() -> void:
	_clear_collision_copies()


func _build() -> void:
	if not is_inside_tree():
		return

	# Limpa tiles antigos
	for tile in _tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	_tiles.clear()
	_clear_collision_copies()

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
	var shape := _find_collision_shape()

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

		var offset := _tile_offset(i, tex_size)

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

		# Colisão: o original já é o tile 0, então só copia a partir do tile 1.
		if shape and i > 0:
			_add_collision_copy(shape, offset)


# ── Posição de cada tile ──────────────────────────────────────

## Deslocamento do tile `i` na direção escolhida (mesma regra para sprite e colisão).
func _tile_offset(i: int, tex_size: Vector2) -> Vector2:
	match direction:
		Direction.DOWN:
			return Vector2(0, round(tex_size.y) * i)
		Direction.UP:
			return Vector2(0, -round(tex_size.y) * i)
		Direction.RIGHT:
			return Vector2(round(tex_size.x) * i, 0)
		Direction.LEFT:
			return Vector2(-round(tex_size.x) * i, 0)
	return Vector2.ZERO


# ── Colisão ───────────────────────────────────────────────────

## Retorna o CollisionShape2D a replicar: o selecionado no Inspector ou, se não
## houver, o único encontrado entre os irmãos e os filhos deste nó.
func _find_collision_shape() -> CollisionShape2D:
	if collision_shape and is_instance_valid(collision_shape):
		return collision_shape

	var found: Array[CollisionShape2D] = []
	var containers: Array[Node] = [self]
	if get_parent():
		containers.append(get_parent())

	for container in containers:
		for child in container.get_children():
			if child is CollisionShape2D \
					and not child.has_meta(COPY_META) \
					and not child.is_queued_for_deletion():
				found.append(child as CollisionShape2D)

	if found.size() == 1:
		return found[0]
	if found.size() > 1:
		push_warning("[TiledSpriteFrames] '%s': vários CollisionShape2D encontrados — selecione um no campo 'collision_shape'." % name)
	return null


## Cria uma cópia do shape deslocada por `offset` (dado no espaço deste nó).
## A cópia vai para o mesmo pai do original, que é quem precisa ser o
## CollisionObject2D (ex: Area2D) para a colisão funcionar.
func _add_collision_copy(shape: CollisionShape2D, offset: Vector2) -> void:
	var shape_parent := shape.get_parent() as Node2D
	if not shape_parent:
		return

	var copy := shape.duplicate() as CollisionShape2D
	copy.set_meta(COPY_META, get_instance_id())
	copy.position = shape.position + _to_parent_space(offset, shape_parent)

	# Mesmo critério dos sprites: no editor só o primeiro tile aparece.
	if Engine.is_editor_hint():
		copy.visible = false

	# Sem `owner` de propósito: as cópias são regeneradas a cada _build e
	# não devem ser salvas dentro da cena.
	shape_parent.add_child(copy)
	_collision_copies.append(copy)


## Converte um deslocamento do espaço deste nó para o espaço do pai do shape.
## Considera escala/rotação de ambos, então funciona mesmo que este nó e o
## shape não estejam alinhados.
func _to_parent_space(offset: Vector2, shape_parent: Node2D) -> Vector2:
	var global_vec := global_transform.basis_xform(offset)
	return shape_parent.global_transform.affine_inverse().basis_xform(global_vec)


## Remove as cópias de colisão criadas por este nó.
## Varre também os possíveis pais por meta, caso a lista tenha sido perdida
## (ex: recarregamento do script no editor).
func _clear_collision_copies() -> void:
	for copy in _collision_copies:
		if is_instance_valid(copy):
			copy.queue_free()
	_collision_copies.clear()

	var containers: Array[Node] = [self]
	if get_parent():
		containers.append(get_parent())
	if collision_shape and is_instance_valid(collision_shape) and collision_shape.get_parent():
		if not containers.has(collision_shape.get_parent()):
			containers.append(collision_shape.get_parent())

	for container in containers:
		for child in container.get_children():
			if child.has_meta(COPY_META) and child.get_meta(COPY_META) == get_instance_id():
				child.queue_free()
