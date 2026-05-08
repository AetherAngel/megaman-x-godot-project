class_name FXComponent
extends Node

## Lista de efeitos configurados no Inspector.
## Cada FXAttachment liga um Def a um marker do nó pai.
@export var attachments: Array[FXAttachment] = []

var _spawners:     Dictionary = {}   # fx_name → FXSpawner
var _stationaries: Dictionary = {}   # fx_name → StationaryFX
var _owner_node:   Node2D     = null


func _ready() -> void:
	_owner_node = get_parent() as Node2D
	if not _owner_node:
		push_error("FXComponent precisa ser filho de um Node2D.")
		return
	call_deferred("_initialize_attachments")


# ── Inicialização ────────────────────────────────────────────

func _initialize_attachments() -> void:
	for attachment in attachments:
		if not attachment or not attachment.effect:
			continue

		var anchor := _resolve_anchor(attachment)

		if attachment.effect is SpawnedParticleDef:
			var spawner := FXSpawner.new()
			spawner.definition      = attachment.effect
			spawner.auto_start      = false
			spawner.position        = attachment.offset
			anchor.add_child(spawner)
			_spawners[attachment.fx_name] = spawner
			if attachment.auto_start:
				spawner.start()

		elif attachment.effect is StationaryParticleDef:
			var sfx := StationaryFX.new()
			anchor.add_child(sfx)
			sfx.setup(attachment.effect)
			sfx.position += attachment.offset
			_stationaries[attachment.fx_name] = sfx
			if attachment.auto_start:
				sfx.set_level(0)

		elif attachment.effect is DynamicParticleDef:
			# DynamicFX não é contínuo por padrão; trigger via trigger_dynamic()
			pass


func _resolve_anchor(attachment: FXAttachment) -> Node2D:
	if not attachment.marker_path.is_empty():
		var marker := _owner_node.get_node_or_null(attachment.marker_path)
		if marker is Node2D:
			return marker
		push_warning("FXComponent: marker_path '%s' não encontrado, usando o pai." % attachment.marker_path)
	return _owner_node


# ── API — Spawners (SpawnedParticleDef) ─────────────────────

func start(fx_name: String) -> void:
	if _spawners.has(fx_name):
		_spawners[fx_name].start()

func stop(fx_name: String) -> void:
	if _spawners.has(fx_name):
		_spawners[fx_name].stop()
	if _stationaries.has(fx_name):
		_stationaries[fx_name].hide_fx()

func set_spawner_direction(fx_name: String, dir: Vector2) -> void:
	if _spawners.has(fx_name):
		_spawners[fx_name].set_direction(dir)

func get_spawner(fx_name: String) -> FXSpawner:
	return _spawners.get(fx_name, null)


# ── API — Stationary (StationaryParticleDef) ─────────────────

func set_level(fx_name: String, level: int, facing_right: bool = true) -> void:
	if _stationaries.has(fx_name):
		_stationaries[fx_name].set_level(level, facing_right)

func hide_fx(fx_name: String) -> void:
	if _stationaries.has(fx_name):
		_stationaries[fx_name].hide_fx()
	if _spawners.has(fx_name):
		_spawners[fx_name].stop()

func set_stationary_position(fx_name: String, pos: Vector2) -> void:
	if _stationaries.has(fx_name):
		_stationaries[fx_name].global_position = pos

func get_stationary(fx_name: String) -> StationaryFX:
	return _stationaries.get(fx_name, null)


# ── API — Dynamic (DynamicParticleDef) ───────────────────────

## Spawna um efeito dinâmico one-shot na posição do marker.
func trigger_dynamic(fx_name: String, direction: Vector2 = Vector2.ZERO) -> void:
	for attachment in attachments:
		if attachment.fx_name != fx_name:
			continue
		if not attachment.effect is DynamicParticleDef:
			continue

		var anchor  := _resolve_anchor(attachment)
		var pos     := (anchor as Node2D).global_position + attachment.offset
		ParticleFX.spawn_dynamic(attachment.effect, pos, direction)
		return


# ── API — Geral ───────────────────────────────────────────────

## Para todos os efeitos ativos de uma vez.
func stop_all() -> void:
	for spawner in _spawners.values():
		spawner.stop()
	for sfx in _stationaries.values():
		sfx.hide_fx()
