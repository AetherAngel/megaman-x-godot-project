# levels/magma_dragon/LavaReactor.gd
class_name LavaReactor
extends Node

## Faz a lava reagir a um projétil que a atravessa: cria um LavaPillar no fosso atingido.
## Fica como filho do LavaRiverEntity (que representa a região de lava) e só escuta — o projétil
## (BallisticProjectile) não sabe que ele existe: avisa o grupo `listener_group` uma vez por
## instância, e todo reactor da fase recebe a chamada.
##
## FLUXO (on_projectile_impact):
##   1. O impacto é desta lava? (ponto dentro da região da LavaHitBox deste entity) Senão, ignora.
##   2. Instancia o pilar (fora da árvore) só para ler o tamanho real dele (config, com escala).
##   3. LavaSpawnFinder acha a posição válida mais próxima (terreno e lava), dentro do limite.
##   4. Ocupação: algum pilar vivo reserva essa área? (PillarHazard.get_reserved_rect, com a escala
##      de CADA pilar — nada de distância fixa)
##        a. Livre ................. nasce ali.
##        b. Ocupada, e o pilar que a ocupa está a <= restart_grace_time do fim do ciclo ..... esse
##           pilar REINICIA (mesmo lugar, mesma instância); nada novo nasce.
##        c. Ocupada ................. procura uma posição ADJACENTE livre; sem espaço, ignora.
##
## LIMITES DA BUSCA
##   - Terreno: só pequenos deslocamentos horizontais (max_search_distance, padrão 32px = metade do
##     Top). Nunca chega a outro fosso: o vizinho mais próximo da fase exige ~55px.
##   - Adjacência: além do limite acima, pode andar o necessário para passar UM pilar existente:
##     metade da largura dele + metade da largura do novo. Não vai mais longe que isso.

signal pillar_spawned(pillar: Node2D)
## Um pilar perto do fim foi reiniciado no lugar de nascer outro.
signal pillar_restarted(pillar: Node2D)
## Houve impacto nesta lava, mas não existe posição válida/livre dentro do limite.
signal spawn_rejected(point: Vector2)

## Arraste lava_pillar.tscn aqui.
@export var pillar_scene: PackedScene
## Atraso (s) entre a Fireball passar e o pilar crescer. Nele só o Top espia o chão, sem hitbox.
@export var pillar_start_delay: float = 1.0
## Se um pilar que ocupa o lugar está a esta distância (s) do fim do ciclo, um novo impacto o
## REINICIA em vez de criar um vizinho. 0 = nunca reinicia.
@export var restart_grace_time: float = 1.0

@export_group("Search")
## Deslocamento horizontal máximo (px) em relação ao ponto de impacto, por causa do terreno.
@export var max_search_distance: float = 32.0
## Passo entre as posições testadas (px).
@export var search_step: float = 2.0
## Grupo das superfícies de lava e layers de física dos obstáculos.
@export var lava_group: StringName = &"unsafe_ground"
@export_flags_2d_physics var obstacle_mask: int = 1

@export_group("Region")
## Área de dano deste entity (Area2D com os CollisionShape2D, inclusive as cópias dos tiles).
## Define "o impacto é meu": o ponto precisa estar nela.
@export var hitbox_path: NodePath = ^"../LavaHitBox"
## Quanto acima do topo da hitbox a superfície da lava pode estar (px). A hitbox começa um pouco
## abaixo da superfície; o ponto de impacto fica na superfície.
@export var surface_margin: float = 16.0
## Deve ser o mesmo grupo/método configurados no BallisticProjectileDef.
@export var listener_group: StringName = &"projectile_impact_listener"


func _ready() -> void:
	add_to_group(listener_group)


## Chamado pelo BallisticProjectile (nome definido em BallisticProjectileDef.listener_method).
func on_projectile_impact(point: Vector2, _normal: Vector2, _collider: Node, projectile: Node) -> void:
	if pillar_scene == null or not _owns(point):
		return
	var pillar := _new_pillar()
	if pillar == null:
		return
	var size := pillar.config.get_footprint_size()
	var finder := LavaSpawnFinder.new(get_viewport().world_2d.direct_space_state, size, lava_group, obstacle_mask)

	var base = finder.find_base(point, max_search_distance, search_step)   # onde o terreno permite
	if base != null:
		var occupants := _occupants(_rect_at(base, size))
		if not occupants.is_empty():
			var ending := _closest_ending(occupants, point.x)
			if ending != null:
				ending.request_restart()
				pillar.free()
				pillar_restarted.emit(ending)
				return
			var limit := max_search_distance + _reach(occupants, size)
			base = finder.find_base(point, limit, search_step,
					func(b: Vector2) -> bool: return _occupants(_rect_at(b, size)).is_empty())

	if base == null:
		pillar.free()
		spawn_rejected.emit(point)
		return
	_spawn(pillar, base, projectile.get_attacker() if projectile and projectile.has_method("get_attacker") else null)


# ── Criação ──────────────────────────────────────────────────

func _new_pillar() -> PillarHazard:
	var pillar := pillar_scene.instantiate() as PillarHazard
	if pillar == null or pillar.config == null:
		push_warning("LavaReactor '%s': pillar_scene precisa ser um PillarHazard com config." % name)
		return null
	if pillar.config.growth_direction != PillarHazardDef.GrowthDirection.UP:
		push_warning("LavaReactor '%s': o pilar da lava precisa crescer para cima." % name)
		pillar.free()
		return null
	return pillar


func _spawn(pillar: PillarHazard, base: Vector2, attacker: Node) -> void:
	pillar.auto_start = true
	pillar.loop = false
	pillar.start_delay = pillar_start_delay
	get_tree().current_scene.add_child(pillar)
	pillar.global_position = base
	_adopt(pillar, attacker)
	pillar_spawned.emit(pillar)


## O boss passa a rastrear o pilar (limpa no reset_for_retry) e vira o atacante do HitComponent.
func _adopt(pillar: Node2D, attacker: Node) -> void:
	if attacker == null:
		return
	var hit := pillar.get_node_or_null("HitComponent") as HitComponent
	if hit:
		hit.attacker = attacker
	if attacker.has_method("bind_spawned_object"):
		attacker.bind_spawned_object(pillar)


# ── Ocupação ─────────────────────────────────────────────────

## Área que um pilar de tamanho `size` ocuparia com a base em `base` (cresce para cima).
func _rect_at(base: Vector2, size: Vector2) -> Rect2:
	return Rect2(base.x - size.x * 0.5, base.y - size.y, size.x, size.y)


## Pilares vivos cuja área reservada se sobrepõe a `rect`. Encostar de leve (lado a lado) é permitido.
func _occupants(rect: Rect2) -> Array[PillarHazard]:
	var found: Array[PillarHazard] = []
	for node in get_tree().get_nodes_in_group(PillarHazard.GROUP):
		var other := node as PillarHazard
		if other and other.occupies_space() and other.get_reserved_rect().intersects(rect, false):
			found.append(other)
	return found


## Entre os ocupantes, o mais perto do impacto que está a <= restart_grace_time do fim (ou null).
func _closest_ending(occupants: Array[PillarHazard], x: float) -> PillarHazard:
	var best: PillarHazard = null
	for other in occupants:
		if other.get_remaining_time() <= restart_grace_time \
				and (best == null or absf(other.global_position.x - x) < absf(best.global_position.x - x)):
			best = other
	return best


## Quanto a busca adjacente pode andar para passar um pilar: metade da largura do MAIOR ocupante
## mais metade da largura do novo — o necessário para encostar do outro lado dele, e só.
func _reach(occupants: Array[PillarHazard], new_size: Vector2) -> float:
	var widest := 0.0
	for other in occupants:
		widest = maxf(widest, other.get_reserved_rect().size.x)
	return (widest + new_size.x) * 0.5


# ── Região ───────────────────────────────────────────────────

## O impacto pertence a esta lava? Região = união das shapes da LavaHitBox, esticada para cima.
func _owns(point: Vector2) -> bool:
	var hitbox := get_node_or_null(hitbox_path)
	if hitbox == null:
		push_warning("LavaReactor '%s': hitbox_path não encontrado." % name)
		return false
	var region := Rect2()
	var first := true
	for child in hitbox.get_children():
		var cs := child as CollisionShape2D
		if cs == null or cs.shape == null:
			continue
		var rect := cs.global_transform * cs.shape.get_rect()
		region = rect if first else region.merge(rect)
		first = false
	if first:
		return false
	return region.grow_individual(1.0, surface_margin, 1.0, 1.0).has_point(point)
