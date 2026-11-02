# levels/magma_dragon/LavaSpawnFinder.gd
class_name LavaSpawnFinder
extends RefCounted

## Ajudante do LavaReactor: acha onde um pilar de lava pode nascer perto de um ponto de impacto.
## Só olha a GEOMETRIA DE COLISÃO real (raios e uma consulta de forma) — não lê células do
## TileMapLayer — então enxerga qualquer obstáculo: terreno, portas, outro TileMapLayer.
##
## Para cada posição candidata (do impacto para os lados, alternando, da mais perto à mais longe):
##   1. SUPERFÍCIE: raios verticais a cada poucos px, de uma borda à outra da largura do pilar,
##      acham o topo da lava. Todos precisam coincidir: a base do pilar não pode ficar no ar.
##   2. ESPAÇO: uma caixa do tamanho REAL do pilar (largura do Top × altura efetiva máxima, já com
##      pillar_scale) apoiada na superfície não pode tocar em nada além da própria lava.
## Devolve a primeira candidata válida — logo, a mais próxima do impacto. Sem nenhuma dentro do
## limite, devolve null (nenhum pilar).

## Quanto acima/abaixo da altura do impacto os raios procuram o topo da lava.
## Cobre degraus de um tile (16px) entre fossos vizinhos.
const _SURFACE_PROBE := 24.0
## Distância (px) entre os raios de apoio. Menor que qualquer detalhe de terreno (tile = 16px),
## para um degrau estreito não passar despercebido entre dois raios.
const _PROBE_SPACING := 8.0
## O topo da lava sob toda a largura do pilar pode variar no máximo isto (px).
const _SURFACE_TOLERANCE := 1.0
## A caixa de validação flutua isto (px) acima da lava, para não tocar na própria superfície.
const _LIFT := 1.0
## Folga total na largura da caixa (px): encostar numa parede não conta como colisão.
const _FIT_TOLERANCE := 1.0
## Quantos obstáculos de outro grupo o raio vertical atravessa até achar a lava.
const _MAX_RAY_HOPS := 8
const _MAX_SHAPE_RESULTS := 16

var _space: PhysicsDirectSpaceState2D
var _footprint: Vector2       # px de MUNDO (já com pillar_scale)
var _lava_group: StringName
var _mask: int


func _init(space: PhysicsDirectSpaceState2D, footprint: Vector2, lava_group: StringName, mask: int) -> void:
	_space = space
	_footprint = footprint
	_lava_group = lava_group
	_mask = mask


## Posição da BASE do pilar (ponto na superfície da lava) ou null.
## `accept` (opcional): Callable(base: Vector2) -> bool para o chamador vetar candidatas por um
## critério que o finder não conhece (ex: espaço já ocupado por outro pilar).
func find_base(point: Vector2, max_distance: float, step: float, accept: Callable = Callable()) -> Variant:
	var s := maxf(step, 0.5)
	var rings := int(floorf(maxf(max_distance, 0.0) / s))
	for i in range(rings + 1):
		for side in ([0.0] if i == 0 else [1.0, -1.0]):   # empate de distância: direita primeiro
			var base = _surface_at(point.x + side * i * s, point.y)
			if base != null and _has_room(base) and (not accept.is_valid() or accept.call(base)):
				return base
	return null


func _surface_at(x: float, ref_y: float) -> Variant:
	var half := _footprint.x * 0.5 - _FIT_TOLERANCE * 0.5
	var count := int(ceilf(half * 2.0 / _PROBE_SPACING)) + 1
	var center_y := 0.0
	var tops: Array[float] = []
	for i in count:
		var y = _lava_top(x - half + (half * 2.0) * i / (count - 1), ref_y)
		if y == null:
			return null
		tops.append(y)
	center_y = tops[count >> 1]
	for y in tops:
		if absf(y - center_y) > _SURFACE_TOLERANCE:
			return null
	return Vector2(x, center_y)


## Y do topo da lava na coluna `px`, ignorando o terreno que estiver no caminho do raio.
func _lava_top(px: float, ref_y: float) -> Variant:
	var query := PhysicsRayQueryParameters2D.create(
			Vector2(px, ref_y - _SURFACE_PROBE), Vector2(px, ref_y + _SURFACE_PROBE), _mask)
	query.collide_with_areas = false
	var excluded: Array[RID] = []
	for _hop in _MAX_RAY_HOPS:
		query.exclude = excluded
		var hit := _space.intersect_ray(query)
		if hit.is_empty():
			return null
		var node := hit.collider as Node
		if node and node.is_in_group(_lava_group) and hit.normal.y < -0.5:   # normal para cima = topo
			return hit.position.y
		excluded.append(hit.rid)
	return null


func _has_room(base: Vector2) -> bool:
	var box := RectangleShape2D.new()
	box.size = Vector2(_footprint.x - _FIT_TOLERANCE, _footprint.y)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(0.0, Vector2(base.x, base.y - _LIFT - _footprint.y * 0.5))
	query.collision_mask = _mask
	query.collide_with_areas = false
	for hit in _space.intersect_shape(query, _MAX_SHAPE_RESULTS):
		var node := hit.collider as Node
		if node and node.is_in_group(_lava_group):
			continue   # a lava em si não é obstáculo
		return false
	return true
