# systems/barrage/BarrageController.gd
class_name BarrageController
extends Node2D

## Executa uma BarrageDef: roda o preamble, escolhe lanes seguras e emite os meteoros.
## A ESCOLHA da lane é independente do que é emitido — hoje o visual (ParticleFX); na etapa
## dos projéteis reais, a mesma escolha alimenta objetos com hitbox. Assim a formação
## validada visualmente é exatamente a que causa dano.
##
## Entra no grupo "fx_continuous": o ParticleFX.stop_all_continuous() (chamado no respawn
## do Player) libera o controller e o preamble — um retry nunca herda uma chuva viva.

## Emitido quando a chuva acabou e o último meteoro pousou.
signal finished

var _def: BarrageDef = null
var _owner_node: Node2D = null
var _rng := RandomNumberGenerator.new()

var _elapsed: float = 0.0
var _next_spawn_at: float = 0.0
var _spawned: int = 0
var _rain_started: bool = false
var _ground_y: float = 0.0
var _dir: Vector2 = Vector2.DOWN
var _preamble_anchor: Node2D = null
var _projectile_scene: PackedScene = null

## Lanes usadas: { "x": X de pouso, "land_at": instante do pouso }.
var _lanes: Array = []
## Só para debug: sorteios rejeitados { "x", "at" }.
var _rejected: Array = []


## Cria e inicia o controller. `owner` é o dono do ataque (boss): fornece o chão
## (posição + ground_offset_y), o marker do preamble e a posição da câmera de referência.
static func start(def: BarrageDef, owner: Node2D) -> BarrageController:
	if not def or not is_instance_valid(owner):
		return null
	var scene := owner.get_tree().current_scene
	if not scene:
		return null
	var controller := BarrageController.new()
	scene.add_child(controller)
	controller._setup(def, owner)
	return controller


func _setup(def: BarrageDef, owner: Node2D) -> void:
	_def = def
	_owner_node = owner
	add_to_group(ParticleFX.CONTINUOUS_GROUP)
	z_index = 100

	if def.seed_value != 0:
		_rng.seed = def.seed_value
	else:
		_rng.randomize()

	var angle := deg_to_rad(def.fall_angle_deg)
	_dir = Vector2(-sin(angle), cos(angle))
	_ground_y = owner.global_position.y + def.ground_offset_y
	_next_spawn_at = def.start_delay

	if def.meteor_object:
		_projectile_scene = load(def.meteor_object.scene_path) as PackedScene
		if not _projectile_scene:
			push_warning("BarrageController: não consegui carregar a cena do meteor_object: %s" % def.meteor_object.scene_path)
	if not _projectile_scene and not def.meteor_fx:
		push_warning("BarrageController: BarrageDef sem meteor_object nem meteor_fx — nenhum meteoro será emitido.")

	# O boss rastreia o controller: reset_for_retry() o libera junto com os projéteis.
	if owner.has_method("bind_spawned_object"):
		owner.bind_spawned_object(self)

	if def.preamble_fx and def.start_delay > 0.0:
		_preamble_anchor = ParticleFX.spawn_continuous(def.preamble_fx, owner.global_position, owner)


func _process(delta: float) -> void:
	if not _def or not is_instance_valid(_owner_node):
		queue_free()
		return

	_elapsed += delta

	if not _rain_started and _elapsed >= _def.start_delay:
		_rain_started = true
		_stop_preamble()

	if _rain_started and _spawn_window_open() and _elapsed >= _next_spawn_at:
		_try_spawn()
		_next_spawn_at = _elapsed + _next_interval()

	if _rain_started and not _spawn_window_open() and not _has_active_lane():
		_finish()
		return

	if _def.debug_draw_lanes:
		queue_redraw()


# ── Escolha da lane ──────────────────────────────────────────

func _try_spawn() -> void:
	_prune_lanes()

	var view := _view_rect()
	var x := _pick_lane_x(view)
	if is_nan(x):
		return  # nenhuma lane segura neste tick: pula, não força

	# Trajeto: do ponto de nascimento (acima da câmera, à direita) até (x, chão).
	var spawn_y := view.position.y - _def.spawn_margin
	var travel := (_ground_y - spawn_y) / _dir.y
	if travel <= 0.0:
		return
	var spawn_pos := Vector2(x, _ground_y) - _dir * travel
	var lifetime := travel / maxf(_def.speed, 1.0)

	var speed := maxf(_def.speed, 1.0)
	if _projectile_scene:
		_spawn_projectile(spawn_pos, speed, lifetime)
	else:
		ParticleFX.spawn_exact(_def.meteor_fx, spawn_pos, _dir, speed, lifetime)
	_lanes.append({"x": x, "land_at": _elapsed + lifetime})
	_spawned += 1


## Projétil real: mesma lane, mesma direção, mesma velocidade do visual.
func _spawn_projectile(pos: Vector2, speed: float, lifetime: float) -> void:
	var node := _projectile_scene.instantiate() as Node2D
	if not node:
		return
	get_tree().current_scene.add_child(node)
	node.global_position = pos
	if node.has_method("fire"):
		node.fire(_dir, speed, lifetime + _def.landing_margin, lifetime)
	else:
		push_warning("BarrageController: a cena do projétil não tem fire(direction, speed, lifetime).")
	if _owner_node.has_method("bind_spawned_object"):
		_owner_node.bind_spawned_object(node, _def.meteor_object)


## Sorteia um X de pouso que respeite todas as regras. NAN = nenhum encontrado.
func _pick_lane_x(view: Rect2) -> float:
	var lo := view.position.x + _def.edge_margin
	var hi := view.end.x - _def.edge_margin
	if hi <= lo:
		return NAN
	for _i in _def.max_attempts:
		var x := _rng.randf_range(lo, hi)
		if _is_lane_free(x):
			return x
		if _def.debug_draw_lanes:
			_rejected.append({"x": x, "at": _elapsed})
	return NAN


## Uma lane está livre se:
##  - nenhum meteoro ATIVO está a menos de min_spacing (nunca menos que lane_width);
##  - nenhum corredor usado, ainda em cooldown depois do pouso, está a menos de lane_width.
func _is_lane_free(x: float) -> bool:
	var active_gap := maxf(_def.min_spacing, _def.lane_width)
	for lane in _lanes:
		var gap := absf(x - float(lane["x"]))
		var land_at: float = lane["land_at"]
		if _elapsed < land_at:
			if gap < active_gap:
				return false
		elif _elapsed < land_at + _def.lane_cooldown:
			if gap < _def.lane_width:
				return false
	return true


func _prune_lanes() -> void:
	_lanes = _lanes.filter(func(lane: Dictionary) -> bool:
		return _elapsed < float(lane["land_at"]) + _def.lane_cooldown
	)


# ── Estado ───────────────────────────────────────────────────

func _spawn_window_open() -> bool:
	if not _projectile_scene and not _def.meteor_fx:
		return false
	if _def.max_total > 0 and _spawned >= _def.max_total:
		return false
	return _elapsed < _def.start_delay + _def.duration


func _has_active_lane() -> bool:
	for lane in _lanes:
		if _elapsed < float(lane["land_at"]):
			return true
	return false


func _next_interval() -> float:
	var jitter := _rng.randf_range(-_def.interval_jitter, _def.interval_jitter)
	return maxf(0.05, _def.spawn_interval + jitter)


## Área visível da câmera em coordenadas de MUNDO (a saraivada cobre a tela, não a sala).
func _view_rect() -> Rect2:
	var vp := get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()


func _stop_preamble() -> void:
	if is_instance_valid(_preamble_anchor):
		_preamble_anchor.queue_free()
	_preamble_anchor = null


func _finish() -> void:
	_stop_preamble()
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	_stop_preamble()


# ── Debug ────────────────────────────────────────────────────

func _draw() -> void:
	if not _def or not _def.debug_draw_lanes:
		return
	var active_gap := maxf(_def.min_spacing, _def.lane_width)
	for lane in _lanes:
		var x := float(lane["x"])
		if _elapsed < float(lane["land_at"]):
			var base := Vector2(x, _ground_y)
			draw_line(base, base - _dir * 400.0, Color(0.3, 0.9, 1.0, 0.7), 1.0)
			draw_rect(Rect2(x - active_gap * 0.5, _ground_y - 3.0, active_gap, 3.0), Color(0.3, 0.9, 1.0, 0.3))
		else:
			draw_rect(Rect2(x - _def.lane_width * 0.5, _ground_y - 3.0, _def.lane_width, 3.0), Color(1.0, 0.6, 0.1, 0.7))
	_rejected = _rejected.filter(func(r: Dictionary) -> bool: return _elapsed - float(r["at"]) < 0.5)
	for r in _rejected:
		var rx := float(r["x"])
		draw_line(Vector2(rx, _ground_y - 10.0), Vector2(rx, _ground_y), Color(1.0, 0.2, 0.2, 0.8), 1.0)
