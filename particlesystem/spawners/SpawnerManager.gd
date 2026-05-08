# SpawnerManager.gd
# Autoload — adicione em Project > Autoloads com o nome "SpawnerManager"
extends Node

signal object_spawned(node: Node, data: ObjectTypeData)
signal object_died(node: Node, data: ObjectTypeData)


# ============================================================
# SPAWN ÚNICO
# ============================================================

func spawn(data: ObjectTypeData, pos: Vector2) -> Node:
	if not data or data.scene_path.is_empty():
		push_error("SpawnerManager: ObjectTypeData inválido ou scene_path vazio.")
		return null

	if not ResourceLoader.exists(data.scene_path):
		push_error("SpawnerManager: cena não encontrada: " + data.scene_path)
		return null

	var node: Node = load(data.scene_path).instantiate()
	get_tree().current_scene.add_child(node)
	node.global_position = pos

	# Grupos
	for tag in data.group_tags:
		node.add_to_group(tag)

	# Efeito de spawn
	if data.spawn_effect:
		ParticleFX.spawn_at(data.spawn_effect, pos)

	object_spawned.emit(node, data)

	# Conecta efeito de morte se o nó tiver o sinal zero_health (Actor)
	if data.death_effect and node.has_signal("zero_health"):
		node.zero_health.connect(func() -> void:
			if is_instance_valid(node):
				ParticleFX.spawn_at(data.death_effect, node.global_position)
			object_died.emit(node, data)
		, CONNECT_ONE_SHOT)

	return node


# ============================================================
# SPAWN EM BATCH — lista de posições
# ============================================================

func spawn_batch(data: ObjectTypeData, positions: Array) -> Array:
	var nodes: Array = []
	for pos in positions:
		var node := spawn(data, pos)
		if node:
			nodes.append(node)
	return nodes


# ============================================================
# SPAWN EM GRUPO — distribui em arco ao redor de um centro
# ============================================================

func spawn_group(
	data:   ObjectTypeData,
	center: Vector2,
	count:  int,
	radius: float
) -> Array:
	var positions: Array = []
	for i in count:
		var angle := (TAU / count) * i
		positions.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return spawn_batch(data, positions)
