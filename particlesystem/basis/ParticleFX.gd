# ParticleFX.gd
# Autoload — adicione em Project > Autoloads com o nome "ParticleFX"
extends Node

var _fx_container: Node2D = null


func _ready() -> void:
	get_tree().tree_changed.connect(_on_tree_changed)


func _on_tree_changed() -> void:
	if not is_instance_valid(_fx_container) or not _fx_container.is_inside_tree():
		_fx_container = null


func _get_container() -> Node2D:
	if is_instance_valid(_fx_container) and _fx_container.is_inside_tree():
		return _fx_container
	var scene := get_tree().current_scene
	if not scene:
		push_warning("ParticleFX: current_scene é null.")
		return null
	_fx_container      = Node2D.new()
	_fx_container.name = "FXContainer"
	scene.add_child(_fx_container)
	return _fx_container


# ============================================================
# SPAWNED PARTICLES
# owner: Node2D opcional — usado para marker_path e inherit_facing.
# ============================================================

func spawn_at(
	def:    SpawnedParticleDef,
	pos:    Vector2,
	normal: Vector2 = Vector2.ZERO,
	owner:  Node2D  = null
) -> void:
	if not def or not def.sprite_frames:
		return

	# spawn_delay — adia tudo sem bloquear
	if def.spawn_delay > 0.0:
		_spawn_delayed(def, pos, normal, owner)
		return

	_do_spawn(def, pos, normal, owner)
	
# Chamado pelo FXSpawner — posição já resolvida, não re-resolve marker_path.
func spawn_at_resolved(def: SpawnedParticleDef, pos: Vector2, normal: Vector2, owner: Node2D) -> void:
	if not def or not def.sprite_frames:
		return
	var dir := _resolve_direction(def, normal, owner)
	for _i in def.burst_count:
		_spawn_single(def, pos, dir, owner)

## Spawna continuamente numa posição fixa do mundo.
## Retorna o anchor — chame anchor.queue_free() para parar.
func spawn_continuous(def: SpawnedParticleDef, pos: Vector2, owner: Node2D = null) -> Node2D:
	var anchor := Node2D.new()
	_get_container().add_child(anchor)
	anchor.global_position = _resolve_pos(def, pos, owner)

	var spawner := FXSpawner.new()
	spawner.definition = def
	spawner.interval   = def.repeat_interval if def.repeat_interval > 0.0 else 0.05
	anchor.add_child(spawner)
	spawner.start()
	return anchor


func _spawn_delayed(def, pos, normal, owner) -> void:
	var captured_pos := _resolve_pos(def, pos, owner)  # captura AGORA
	await get_tree().create_timer(def.spawn_delay).timeout
	if not is_inside_tree():
		return
	_do_spawn(def, captured_pos, normal, null)  # owner = null, posição já resolvida
	

func _do_spawn(def: SpawnedParticleDef, pos: Vector2, normal: Vector2, owner: Node2D) -> void:
	var spawn_pos := _resolve_pos(def, pos, owner)
	var dir       := _resolve_direction(def, normal, owner)

	if def.spawn_interval > 0.0 and def.burst_count > 1:
		_spawn_burst_delayed(def, spawn_pos, dir, owner)
	else:
		for _i in def.burst_count:
			_spawn_single(def, spawn_pos, dir, owner)


func _resolve_pos(def: SpawnedParticleDef, fallback: Vector2, owner: Node2D) -> Vector2:
	if owner and not def.marker_path.is_empty():
		var marker := owner.get_node_or_null(NodePath(def.marker_path))
		if marker is Node2D:
			return (marker as Node2D).global_position
	return fallback


func _resolve_direction(def: SpawnedParticleDef, normal: Vector2, owner: Node2D) -> Vector2:
	var dir := Vector2.UP

	if def.inherit_normal and normal != Vector2.ZERO:
		dir = normal.normalized()
	elif def.base_direction != Vector2.ZERO:
		dir = def.base_direction.normalized()

	# Espelha X se o dono estiver virado para a esquerda
	if def.inherit_facing and owner and owner.get("facing_right") != null:
		if not owner.facing_right:
			dir.x = -dir.x

	return dir


func _spawn_burst_delayed(def: SpawnedParticleDef, pos: Vector2, dir: Vector2, owner: Node2D) -> void:
	for i in def.burst_count:
		# Atualiza posição do marker a cada step do burst se follow_marker
		var spawn_pos := _resolve_pos(def, pos, owner) if def.follow_marker else pos
		_spawn_single(def, spawn_pos, dir, owner)
		if i < def.burst_count - 1:
			await get_tree().create_timer(def.spawn_interval).timeout
			if not is_inside_tree():
				return


func _spawn_single(def: SpawnedParticleDef, pos: Vector2, base_dir: Vector2, owner: Node2D) -> void:
	var container := _get_container()
	if not container:
		return

	if def.require_grounded and owner and owner.has_method("is_on_floor"):
		if not owner.is_on_floor():
			return

	var angle_rad  := deg_to_rad(randf_range(-def.spread_angle * 0.5, def.spread_angle * 0.5))
	var spread_dir := base_dir.rotated(angle_rad).normalized()
	var speed      := randf_range(def.velocity_min, def.velocity_max)

	var instance := ParticleInstance.new()
	container.add_child(instance)
	instance.global_position = pos
	instance.setup(def, spread_dir, speed, owner)
	_play_def_sfx(def)
	
	

# ============================================================
# DYNAMIC PARTICLES
# ============================================================

func spawn_dynamic(
	def:       DynamicParticleDef,
	pos:       Vector2,
	direction: Vector2 = Vector2.ZERO
) -> void:
	if not def or def.phases.is_empty():
		return
	var container := _get_container()
	if not container:
		return
	for _i in def.burst_count:
		var angle_rad := deg_to_rad(randf_range(-def.spread_angle * 0.5, def.spread_angle * 0.5))
		var dir := direction.rotated(angle_rad).normalized() if direction != Vector2.ZERO else Vector2.ZERO
		var speed := randf_range(def.velocity_min, def.velocity_max)
		var fx := DynamicFX.new()
		container.add_child(fx)
		fx.global_position = pos
		fx.setup(def, dir * speed)
	_play_def_sfx(def)


# ============================================================
# SHOOT EFFECT
# ============================================================

func spawn_shoot_effect(
	def:          ShootEffectDef,
	pos:          Vector2,
	facing_right: bool
) -> void:
	if not def or not def.sprite_frames:
		return
	var container := _get_container()
	if not container:
		return
	var flip     := 1 if facing_right else -1
	var offset   := Vector2(def.offset.x * flip, def.offset.y)
	var instance := ShootEffectInstance.new()
	container.add_child(instance)
	instance.global_position = pos + offset
	instance.setup(def, facing_right)
	_play_def_sfx(def)


# ============================================================
# SFX HELPER
# ============================================================

func _play_def_sfx(def: Resource) -> void:
	if not def:
		return
	var do_play: bool  = def.get("play_sfx") if def.get("play_sfx") != null else false
	var sfx_id: String = def.get("sfx_id")   if def.get("sfx_id")   != null else ""
	if not do_play or sfx_id.is_empty():
		return
	var vol:   float = def.get("sfx_volume") if def.get("sfx_volume") != null else INF
	var pitch: float = def.get("sfx_pitch")  if def.get("sfx_pitch")  != null else INF
	SoundManager.play_sfx(sfx_id, vol, pitch)


# ============================================================
# HELPERS
# ============================================================

func create_spawner(def: SpawnedParticleDef, parent: Node2D, offset: Vector2 = Vector2.ZERO) -> FXSpawner:
	var spawner       := FXSpawner.new()
	spawner.definition = def
	spawner.position   = offset
	parent.add_child(spawner)
	return spawner


func create_stationary(def: StationaryParticleDef, parent: Node2D, offset: Vector2 = Vector2.ZERO) -> StationaryFX:
	var sfx := StationaryFX.new()
	parent.add_child(sfx)
	sfx.setup(def)
	sfx.position += offset
	return sfx
