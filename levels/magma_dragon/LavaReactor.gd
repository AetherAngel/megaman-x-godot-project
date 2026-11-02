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
##   3. LavaSpawnFinder procura a posição válida mais próxima, dentro de `max_search_distance`.
##   4. Achou: configura o pilar (one-shot, start_delay) e adiciona à cena. Não achou: nada nasce.
##
## LIMITE DA BUSCA: só pequenos deslocamentos horizontais para fugir de parede/terreno. Nunca para
## outro fosso: o padrão (32px) é metade do Top, e o fosso vizinho mais próximo da fase exige
## ~55px de deslocamento (48px de terreno entre eles + meia largura do Top).

signal pillar_spawned(pillar: Node2D)
## Houve impacto nesta lava, mas não existe posição válida dentro do limite.
signal spawn_rejected(point: Vector2)

## Arraste lava_pillar.tscn aqui.
@export var pillar_scene: PackedScene
## Atraso (s) entre a Fireball passar e o pilar crescer. Nele só o Top espia o chão, sem hitbox.
@export var pillar_start_delay: float = 1.0

@export_group("Search")
## Deslocamento horizontal máximo (px) em relação ao ponto de impacto.
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
	var pillar := pillar_scene.instantiate() as PillarHazard
	if pillar == null or pillar.config == null:
		push_warning("LavaReactor '%s': pillar_scene precisa ser um PillarHazard com config." % name)
		return
	if pillar.config.growth_direction != PillarHazardDef.GrowthDirection.UP:
		push_warning("LavaReactor '%s': o pilar da lava precisa crescer para cima." % name)
		pillar.free()
		return

	var finder := LavaSpawnFinder.new(get_viewport().world_2d.direct_space_state,
			pillar.config.get_footprint_size(), lava_group, obstacle_mask)
	var base = finder.find_base(point, max_search_distance, search_step)
	if base == null:
		pillar.free()
		spawn_rejected.emit(point)
		return

	pillar.auto_start = true
	pillar.loop = false
	pillar.start_delay = pillar_start_delay
	get_tree().current_scene.add_child(pillar)
	pillar.global_position = base
	_adopt(pillar, projectile.get_attacker() if projectile and projectile.has_method("get_attacker") else null)
	pillar_spawned.emit(pillar)


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


## O boss passa a rastrear o pilar (limpa no reset_for_retry) e vira o atacante do HitComponent.
func _adopt(pillar: Node2D, attacker: Node) -> void:
	if attacker == null:
		return
	var hit := pillar.get_node_or_null("HitComponent") as HitComponent
	if hit:
		hit.attacker = attacker
	if attacker.has_method("bind_spawned_object"):
		attacker.bind_spawned_object(pillar)
