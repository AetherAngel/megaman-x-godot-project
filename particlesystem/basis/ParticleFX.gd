# ParticleFX.gd
# Autoload — adicione em Project > Autoloads com o nome "ParticleFX"
extends Node

## Grupo das âncoras de FX em ondas. Dá para parar tudo de uma vez (stop_all_continuous)
## ou por cutscene: StepCall com target_group "fx_continuous" e method "queue_free".
const CONTINUOUS_GROUP := &"fx_continuous"

## Muda em stop_all_continuous(): invalida TODOS os spawns pendentes que não receberam
## um `cancel` próprio (ex: burst temporizado do death_effect). Cada corrotina captura
## a geração ao começar e desiste se ela mudou.
var _generation: int = 0

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
# owner: Node2D opcional — usado para marker_path, offset, follow_marker e inherit_facing.
# cancel: Callable opcional que devolve true quando a SEQUÊNCIA foi encerrada (ex: o Step
#   de uma cutscene acabou). Spawns ainda pendentes (burst, delay, ondas) não nascem depois
#   disso. O que já nasceu fica. Sem cancel, o comportamento é o de sempre.
# ============================================================

func spawn_at(
	def:    SpawnedParticleDef,
	pos:    Vector2,
	normal: Vector2 = Vector2.ZERO,
	owner:  Node2D  = null,
	cancel: Callable = Callable()
) -> void:
	if not def or not def.sprite_frames:
		return

	# Wave (opt-in): repete o burst a cada repeat_interval, sempre da posição ORIGINAL.
	if def.wave:
		if def.repeat_interval > 0.0:
			_spawn_waves(def, pos, owner, cancel)
			return
		push_warning("ParticleFX: 'Wave' ligado mas repeat_interval = 0 — spawnando uma vez só.")

	# spawn_delay — adia tudo sem bloquear
	if def.spawn_delay > 0.0:
		_spawn_delayed(def, pos, normal, owner, cancel)
		return

	_do_spawn(def, pos, normal, owner, cancel)
	
# Chamado pelo FXSpawner — posição já resolvida, não re-resolve marker_path.
func spawn_at_resolved(def: SpawnedParticleDef, pos: Vector2, normal: Vector2, owner: Node2D) -> void:
	if not def or not def.sprite_frames:
		return
	var dir := _resolve_direction(def, normal, owner)
	for i in def.burst_count:
		_spawn_single(def, pos, dir, owner, i)

## Spawna continuamente numa posição fixa do mundo (ondas).
## Retorna o anchor — chame anchor.queue_free() para parar. Para sozinho depois de
## def.repeat_duration (se > 0) e também em stop_all_continuous().
func spawn_continuous(def: SpawnedParticleDef, pos: Vector2, owner: Node2D = null, cancel: Callable = Callable()) -> Node2D:
	var container := _get_container()
	if not container:
		return null

	var anchor := Node2D.new()
	container.add_child(anchor)
	anchor.global_position = _resolve_pos(def, pos, owner)
	anchor.add_to_group(CONTINUOUS_GROUP)

	var spawner := FXSpawner.new()
	spawner.definition   = def
	spawner.interval     = def.repeat_interval if def.repeat_interval > 0.0 else 0.05
	spawner.cancel       = cancel
	spawner.owner_anchor = anchor
	anchor.add_child(spawner)
	spawner.start()

	if def.repeat_duration > 0.0:
		get_tree().create_timer(def.repeat_duration).timeout.connect(func() -> void:
			if is_instance_valid(anchor):
				anchor.queue_free()
		)
	return anchor


## Para todas as ondas em andamento.
## Para todas as ondas em andamento e cancela os spawns pendentes sem `cancel` próprio.
func stop_all_continuous() -> void:
	_generation += 1
	get_tree().call_group(CONTINUOUS_GROUP, "queue_free")


## Ondas a partir de spawn_at: a origem é resolvida uma única vez (agora; ou, se a posição
## depende do dono e há spawn_delay, quando o atraso termina) e nunca segue o dono, então
## toda onda nasce do ponto original. Respeita spawn_delay antes da primeira onda.
func _spawn_waves(def: SpawnedParticleDef, pos: Vector2, owner: Node2D, cancel: Callable = Callable()) -> void:
	var origin := _resolve_pos(def, pos, owner)  # captura AGORA
	# Posição relativa ao dono + atraso: o atraso só decide QUANDO a onda começa. A origem é
	# resolvida quando ele termina (ver _spawn_delayed); sem dono válido, vale a de agora.
	var relative := owner != null and def.spawn_delay > 0.0 and _is_owner_relative(def)
	var caller_delta := (pos - owner.global_position) if relative else Vector2.ZERO
	var gen := _generation
	if def.spawn_delay > 0.0:
		await get_tree().create_timer(def.spawn_delay).timeout
		if not is_inside_tree() or _is_cancelled(gen, cancel):
			return
		if relative and is_instance_valid(owner):
			origin = _resolve_pos(def, owner.global_position + caller_delta, owner)
	spawn_continuous(def, origin, null, cancel)  # owner = null: origem já resolvida (offset 1x)


func _spawn_delayed(def, pos, normal, owner, cancel: Callable = Callable()) -> void:
	var captured_pos := _resolve_pos(def, pos, owner)  # captura AGORA
	# Posição relativa ao dono (marker, offset ou follow): o atraso só decide QUANDO o FX
	# aparece, não ONDE. A posição é resolvida no instante em que o atraso termina, como se a
	# chamada tivesse acontecido ali — o FX nasce uma vez só, já no lugar certo, sem nascer em
	# um ponto e ser corrigido depois. Se o dono sumiu, vale a posição de quando foi chamado.
	# Defs sem lógica relativa ao dono continuam capturando a posição AGORA, como sempre.
	var relative: bool = owner != null and _is_owner_relative(def)
	var caller_delta: Vector2 = (pos - owner.global_position) if relative else Vector2.ZERO
	var gen := _generation
	await get_tree().create_timer(def.spawn_delay).timeout
	if not is_inside_tree() or _is_cancelled(gen, cancel):
		return
	if relative and is_instance_valid(owner):
		_do_spawn(def, owner.global_position + caller_delta, normal, owner, cancel)
		return
	_do_spawn(def, captured_pos, normal, null, cancel)  # owner = null, posição já resolvida
	

func _do_spawn(def: SpawnedParticleDef, pos: Vector2, normal: Vector2, owner: Node2D, cancel: Callable = Callable()) -> void:
	var spawn_pos := _resolve_pos(def, pos, owner)
	var dir       := _resolve_direction(def, normal, owner)

	if def.spawn_interval > 0.0 and def.burst_count > 1:
		_spawn_burst_delayed(def, spawn_pos, dir, owner, cancel)
	else:
		for i in def.burst_count:
			_spawn_single(def, spawn_pos, dir, owner, i)


## Posição de nascimento: referência (marker, se existir; senão a posição passada) + def.offset.
## Sem `owner` não há referência: a posição já é final e o offset NÃO é aplicado — é a convenção
## que _spawn_delayed e as ondas usam para dizer "posição já resolvida", e é o que torna esta
## função segura de chamar de novo sobre um valor já resolvido (o offset entra uma única vez).
func _resolve_pos(def: SpawnedParticleDef, fallback: Vector2, owner: Node2D) -> Vector2:
	if not owner:
		return fallback
	var base := fallback
	if not def.marker_path.is_empty():
		var marker := owner.get_node_or_null(NodePath(def.marker_path))
		if marker is Node2D:
			base = marker_global_position(def, owner, marker as Node2D)
	return base + _mirrored_offset(def, owner)


## def.offset com o X espelhado pelo mesmo critério do marker: orientação NATIVA do dono
## (owner.get_facing_flip()), nunca uma convenção global. Espelhar a POSIÇÃO (esta flag) é
## independente de espelhar a ARTE do FX (def.inherit_facing).
func _mirrored_offset(def: SpawnedParticleDef, owner: Node2D) -> Vector2:
	if def.offset == Vector2.ZERO:
		return Vector2.ZERO
	return Vector2(def.offset.x * _facing_flip_for(def, owner), def.offset.y)


## True se a posição do def depende do dono (marker, offset ou follow).
func _is_owner_relative(def: SpawnedParticleDef) -> bool:
	return not def.marker_path.is_empty() or def.offset != Vector2.ZERO or def.follow_marker


## Posição global do marker. Com def.mirror_marker_with_facing, o X é espelhado em torno do
## pivô do dono quando ele olha para o lado oposto ao da arte nativa (owner.get_facing_flip()).
## Ponto único de resolução: o ParticleInstance (follow_marker) também passa por aqui.
func marker_global_position(def: SpawnedParticleDef, owner: Node2D, marker: Node2D) -> Vector2:
	if not def.mirror_marker_with_facing or not owner.has_method("get_facing_flip"):
		return marker.global_position
	var local := owner.to_local(marker.global_position)
	local.x *= float(owner.get_facing_flip())
	return owner.to_global(local)


# ── Follow: referência + deslocamento ────────────────────────
# O follow guarda, no nascimento, o DESLOCAMENTO do FX em relação a uma referência (o marker,
# se houver; senão o pivô do dono), na orientação NATIVA do dono (X desespelhado). A cada
# frame, referência atual + deslocamento re-espelhado pela orientação ATUAL dão a posição.
# Guardar o deslocamento (e não recalcular def.offset) preserva o position_variance e o
# deslocamento do chamador, e torna o follow idempotente: nada é somado duas vezes.

## Marker do follow: o nó de def.marker_path, se existir (qualquer Node2D). null = segue o pivô.
func find_follow_marker(def: SpawnedParticleDef, owner: Node2D) -> Node2D:
	if def.marker_path.is_empty():
		return null
	return owner.get_node_or_null(NodePath(def.marker_path)) as Node2D


## Referência do follow: o marker (espelhado como sempre) ou, sem marker, o pivô do dono.
func follow_reference(def: SpawnedParticleDef, owner: Node2D, marker: Node2D) -> Vector2:
	if marker != null:
		return marker_global_position(def, owner, marker)
	return owner.global_position


## Deslocamento de `world_pos` em relação à referência, na orientação NATIVA do dono.
func follow_delta_native(def: SpawnedParticleDef, owner: Node2D, reference: Vector2, world_pos: Vector2) -> Vector2:
	var d := world_pos - reference
	d.x *= _facing_flip_for(def, owner)
	return d


## Posição de follow: referência atual + deslocamento nativo espelhado pela orientação ATUAL.
func follow_point(def: SpawnedParticleDef, owner: Node2D, reference: Vector2, native_delta: Vector2) -> Vector2:
	var d := native_delta
	d.x *= _facing_flip_for(def, owner)
	return reference + d


## +1/-1 pela orientação NATIVA do dono (get_facing_flip); +1 se a flag de espelho está
## desligada ou se o dono não tem orientação (ex.: Player). Ponto único dessa regra.
func _facing_flip_for(def: SpawnedParticleDef, owner: Node2D) -> float:
	if def.mirror_marker_with_facing and owner.has_method("get_facing_flip"):
		return float(owner.get_facing_flip())
	return 1.0


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


## Burst temporizado: burst_count spawns INDIVIDUAIS, um a cada spawn_interval (o intervalo
## separa o início de um spawn do início do próximo). Cada espera é seguida de uma checagem
## de cancelamento: se a sequência acabou, os spawns restantes não acontecem.
func _spawn_burst_delayed(def: SpawnedParticleDef, pos: Vector2, dir: Vector2, owner: Node2D, cancel: Callable = Callable()) -> void:
	var gen := _generation
	# Com follow_marker, cada step nasce na referência ATUAL do dono (marker ou pivô) mais o mesmo
	# deslocamento do primeiro step — o mesmo cálculo com que o ParticleInstance segue o dono —
	# em vez de voltar ao ponto onde o dono estava quando o burst começou.
	var following := def.follow_marker and owner != null and is_instance_valid(owner)
	var marker: Node2D = null
	var has_marker := false
	var delta_native := Vector2.ZERO
	if following:
		marker = find_follow_marker(def, owner)
		has_marker = marker != null
		delta_native = follow_delta_native(def, owner, follow_reference(def, owner, marker), pos)
	var spawn_pos := pos
	for i in def.burst_count:
		if following:
			if is_instance_valid(owner) and (not has_marker or is_instance_valid(marker)):
				spawn_pos = follow_point(def, owner, follow_reference(def, owner, marker), delta_native)
			else:
				following = false  # dono ou marker sumiram: mantém a última posição
		_spawn_single(def, spawn_pos, dir, owner, i)
		if i < def.burst_count - 1:
			await get_tree().create_timer(def.spawn_interval).timeout
			if not is_inside_tree() or _is_cancelled(gen, cancel):
				return


## Ângulo (graus, relativo à direção base) da partícula `index` do burst.
## Aleatório por padrão; igualmente espaçado se def.even_spread.
func _spread_angle_deg(def: SpawnedParticleDef, index: int) -> float:
	if not def.even_spread or def.burst_count <= 1:
		return randf_range(-def.spread_angle * 0.5, def.spread_angle * 0.5)
	# Anel completo: N passos iguais, sem repetir o ângulo inicial (0° == 360°).
	if def.spread_angle >= 360.0:
		return def.spread_angle * float(index) / float(def.burst_count)
	# Arco: extremos incluídos.
	return -def.spread_angle * 0.5 + def.spread_angle * float(index) / float(def.burst_count - 1)


## True se a sequência foi cancelada: por geração (stop_all_continuous) ou pelo `cancel` próprio.
func _is_cancelled(gen: int, cancel: Callable) -> bool:
	return gen != _generation or (cancel.is_valid() and cancel.call())


## Deslocamento aleatório dentro de ±variance por eixo. Zero devolve Vector2.ZERO.
func _random_offset(variance: Vector2) -> Vector2:
	return Vector2(randf_range(-variance.x, variance.x), randf_range(-variance.y, variance.y))


func _spawn_single(def: SpawnedParticleDef, pos: Vector2, base_dir: Vector2, owner: Node2D, index: int = 0) -> void:
	var container := _get_container()
	if not container:
		return

	if def.require_grounded and owner and owner.has_method("is_on_floor"):
		if not owner.is_on_floor():
			return

	var angle_rad  := deg_to_rad(_spread_angle_deg(def, index))
	var spread_dir := base_dir.rotated(angle_rad).normalized()
	var speed      := randf_range(def.velocity_min, def.velocity_max)

	var instance := ParticleInstance.new()
	container.add_child(instance)
	instance.global_position = pos + _random_offset(def.position_variance)
	instance.setup(def, spread_dir, speed, owner)
	# Anel regular: um som só para o burst inteiro (senão 8 partículas = 8 sons).
	if not def.even_spread or index == 0:
		_play_def_sfx(def)
	
	

## Spawna UMA partícula com direção, velocidade e vida EXATAS (sem spread, sem sorteio).
## Para quem calcula a trajetória por conta própria (ex: BarrageController).
## O fade_out do def usa essa vida — desligue-o se a partícula deve sumir fora da tela.
func spawn_exact(def: SpawnedParticleDef, pos: Vector2, dir: Vector2, speed: float, lifetime: float) -> void:
	if not def or not def.sprite_frames:
		return
	var container := _get_container()
	if not container:
		return
	var instance := ParticleInstance.new()
	container.add_child(instance)
	instance.global_position = pos
	instance.setup(def, dir.normalized(), speed)
	instance.set_lifetime(lifetime)
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
# CHAIN (FXChainDef) — cadeias segmentadas que perseguem uma cabeça
# ============================================================

## Cria uma cadeia segmentada (cauda de fogo, corpo de dragão, chicote...)
## cujo Segmento 1 persegue `head` (a cabeça de verdade — o objeto que se
## move). Retorna o controller: guarde a referência pra chamar on_hit()
## quando a cabeça colidir com algo.
func spawn_chain(def: FXChainDef, head: Node2D) -> FXChainController:
	if not def or not def.segment_def or not is_instance_valid(head):
		return null
	var container := _get_container()
	if not container:
		return null
	var controller := FXChainController.new()
	container.add_child(controller)
	controller.global_position = head.global_position
	controller.setup(def, head)
	return controller


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
