extends Node2D
## [HITBOX · BATCH 1 — VALIDAÇÃO TEMPORÁRIA — remover ao fim da tarefa de hitbox]
##
## Testa o núcleo isolado: HitboxDef + HitboxArea, SEM Boss, SEM FrameEvent, SEM BossAction.
## Mesmo molde do harness da A2, só com cenários [NEW] (recurso novo, expectativa calculada aqui).
##
## COMO USAR
##   1. Rode res://_hitbox_validation/HitboxCore.tscn (F6). Todos os ASSERT devem dar PASS.
##   2. Resultado no Output e em user://hitbox_core_<label>.txt.
##   3. A regressão do Boss NÃO é aqui: rode também o HitboxBaseline.tscn com um label novo
##      (ex.: b1) e confirme "diff vazio" — o Batch 1 só ADICIONA arquivos, então tem que
##      dar vazio.
##
## TESTE-CHAVE DE REUTILIZAÇÃO (NEW_reuse_bare_owner_*): o dono é um Node2D "pelado" — sem
## Boss, sem Sprite, sem get_facing_flip — e mesmo assim a hitbox nasce, atinge o alvo e some.

@export var label: String = "core"

const LAYER_PLAYER: int = 4

## Alvo: registra o que o HitBus entrega a take_damage() (como o Player: layer 4).
class FakeBody extends CharacterBody2D:
	var received: Array[Dictionary] = []
	func take_damage(value: float, inflicter: Node) -> void:
		received.append({"value": value, "type": inflicter.get_damage_type_id(), "tag": inflicter.get_damage_tag()})

## Dono com facing (como Actor/Boss).
class FlipOwner extends Node2D:
	var flip: int = 1
	func get_facing_flip() -> int:
		return flip

var _nodes: Array[Node] = []
var _lines: PackedStringArray = []
var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("label="):
			label = a.substr(6)
	await get_tree().process_frame
	await _run_all()
	_finish()
	get_tree().quit(1 if _fail > 0 else 0)


# ============================================================
# Infra
# ============================================================

func _expect(test_name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
	var line := "ASSERT|%s|%s|%s" % [test_name, "PASS" if cond else "FAIL", detail]
	_lines.append(line)
	print(line)


func _scenario(sid: String, body: Callable) -> void:
	_lines.append("=== %s [NEW] ===" % sid)
	await body.call()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await get_tree().physics_frame
	await get_tree().process_frame


func _phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _track(n: Node) -> Node:
	add_child(n)
	_nodes.append(n)
	return n


func _profile(damage: float = 8.0, type_id: StringName = &"fire", tag: String = "fire") -> DamageProfile:
	var p := DamageProfile.new()
	p.damage = damage
	p.damage_type_id = type_id
	p.damage_tag = tag
	return p


func _def(size: Vector2 = Vector2(20, 10)) -> HitboxDef:
	var d := HitboxDef.new()
	d.size = size
	d.profile = _profile()
	return d


func _owner_plain(pos: Vector2 = Vector2.ZERO) -> Node2D:
	var o := Node2D.new()
	o.position = pos
	return _track(o) as Node2D


func _owner_flip(pos: Vector2 = Vector2.ZERO) -> FlipOwner:
	var o := FlipOwner.new()
	o.position = pos
	return _track(o) as FlipOwner


func _target(pos: Vector2 = Vector2.ZERO, layer: int = LAYER_PLAYER) -> FakeBody:
	var b := FakeBody.new()
	b.collision_layer = layer
	b.collision_mask = 0
	b.position = pos
	var col := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size = Vector2(16, 16)
	col.shape = shp
	b.add_child(col)
	_track(b)
	return b


func _sprite(anim: String, frames_count: int) -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	for a in ["a", "b"]:
		if not sf.has_animation(a):
			sf.add_animation(a)
		sf.set_animation_loop(a, false)
		var tex := PlaceholderTexture2D.new()
		for i in frames_count:
			sf.add_frame(a, tex)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.process_mode = Node.PROCESS_MODE_DISABLED   # os frames são avançados à mão
	_track(s)
	s.animation = anim
	s.frame = 0
	return s


func _left_edge(a: HitboxArea) -> float:
	return a._col.position.x - a._shape.size.x * 0.5


func _right_edge(a: HitboxArea) -> float:
	return a._col.position.x + a._shape.size.x * 0.5


## A hitbox expirada é liberada no fim do frame: "sumiu" = já liberada OU marcada como expirada.
func _is_gone(a: Variant) -> bool:
	return not is_instance_valid(a) or a._expired


func _ticks_until_gone(a: Variant, limit: int = 60) -> int:
	var t: int = 0
	while not _is_gone(a) and t < limit:
		await get_tree().physics_frame
		t += 1
	return t


func _near(a: float, b: float) -> bool:
	return absf(a - b) <= 0.001


# ============================================================
# Cenários
# ============================================================

func _run_all() -> void:
	await _scenario("NEW_api_present", _t_api)
	await _scenario("NEW_spawn_basics", _t_spawn_basics)
	await _scenario("NEW_spawn_invalid_inputs", _t_invalid)
	await _scenario("NEW_reuse_bare_owner_no_boss_no_sprite_idle", func() -> void: await _t_reuse_bare(false))
	await _scenario("NEW_reuse_bare_owner_no_boss_no_sprite_physics", func() -> void: await _t_reuse_bare(true))
	await _scenario("NEW_no_hit_out_of_range", _t_out_of_range)
	await _scenario("NEW_mask_respected", _t_mask)
	await _scenario("NEW_one_hit_per_activation", _t_one_hit)
	await _scenario("NEW_lifetime_never_shorter_than_duration", _t_lifetime)
	await _scenario("NEW_growth_anchor_fixed", _t_growth)
	await _scenario("NEW_growth_max_size_cap", _t_max_cap)
	await _scenario("NEW_growth_min_size_floor", _t_min_floor)
	await _scenario("NEW_follows_owner", _t_follows)
	await _scenario("NEW_facing_mirror", _t_mirror)
	await _scenario("NEW_clear_by_token_and_id", _t_clear)
	await _scenario("NEW_safety_timeout", _t_safety)
	await _scenario("NEW_frame_source_counts_animation_frames", _t_frame_source)
	await _scenario("NEW_frame_source_animation_change_expires", _t_anim_change)
	await _scenario("NEW_shared_def_two_owners_independent", _t_shared_def)
	await _scenario("NEW_owner_freed_frees_hitbox", _t_owner_freed)


func _t_api() -> void:
	_expect("NEW_api/HitboxDef_exists", ResourceLoader.exists("res://systems/hitbox/HitboxDef.gd"))
	_expect("NEW_api/HitboxArea_exists", ResourceLoader.exists("res://systems/hitbox/HitboxArea.gd"))
	var d := HitboxDef.new()
	_expect("NEW_api/defaults", d.duration_frames == 1 and d.target_mask == 4 and d.priority == 0 and d.profile == null,
		"duration=%d mask=%d priority=%d" % [d.duration_frames, d.target_mask, d.priority])


func _t_spawn_basics() -> void:
	var o := _owner_plain(Vector2(30, 40))
	var d := _def(Vector2(20, 10))
	d.duration_frames = 0
	var a := HitboxArea.spawn(d, o)
	_expect("NEW_spawn/not_null", a != null)
	if a == null:
		return
	_expect("NEW_spawn/child_of_owner", a.get_parent() == o)
	_expect("NEW_spawn/detects_only", a.monitoring and not a.monitorable and a.collision_layer == 0,
		"monitoring=%s monitorable=%s layer=%d" % [str(a.monitoring), str(a.monitorable), a.collision_layer])
	_expect("NEW_spawn/mask_from_def", a.collision_mask == 4, "mask=%d" % a.collision_mask)
	_expect("NEW_spawn/initial_size", a._shape.size == Vector2(20, 10), str(a._shape.size))
	_expect("NEW_spawn/shape_not_shared", a._shape != null and a._col.shape == a._shape)
	var hc := a.get_node_or_null("HitComponent") as HitComponent
	_expect("NEW_spawn/hitcomponent_profile", hc != null and _near(hc.get_damage(), 8.0) and hc.get_damage_type_id() == &"fire" and hc.get_damage_tag() == "fire",
		"dano=%s" % str(hc.get_damage() if hc else "sem HitComponent"))
	_expect("NEW_spawn/attacker_is_owner", hc != null and hc.get_attacker() == o)
	_expect("NEW_spawn/count_active", HitboxArea.count_active(o) == 1)
	HitboxArea.clear(o)


func _t_invalid() -> void:
	var o := _owner_plain()
	_expect("NEW_invalid/null_def", HitboxArea.spawn(null, o) == null)
	var no_profile := HitboxDef.new()
	_expect("NEW_invalid/def_without_profile", HitboxArea.spawn(no_profile, o) == null)
	_expect("NEW_invalid/null_owner", HitboxArea.spawn(_def(), null) == null)
	_expect("NEW_invalid/clear_null_owner", HitboxArea.clear(null) == 0)
	_expect("NEW_invalid/clear_without_hitboxes", HitboxArea.clear(o) == 0)
	_expect("NEW_invalid/nothing_spawned", HitboxArea.count_active(o) == 0)


## O teste que importa: dono "pelado" (sem Boss, sem Sprite, sem get_facing_flip), hitbox de
## 1 frame (a duração padrão), alvo já sobreposto: tem que entregar EXATAMENTE 1 hit e sumir.
func _t_reuse_bare(from_physics: bool) -> void:
	var o := _owner_plain()
	var t := _target()
	await _phys(2)   # o alvo precisa estar registrado no mundo de física
	if from_physics:
		await get_tree().physics_frame
	else:
		await get_tree().process_frame
	var a := HitboxArea.spawn(_def(), o)   # duration_frames = 1 (padrão)
	_expect("NEW_reuse_bare/spawned", a != null)
	await _phys(6)
	_expect("NEW_reuse_bare/exactly_one_hit", t.received.size() == 1, "hits=%d" % t.received.size())
	if t.received.size() == 1:
		var r: Dictionary = t.received[0]
		_expect("NEW_reuse_bare/hit_values", _near(float(r["value"]), 8.0) and r["type"] == &"fire" and r["tag"] == "fire", str(r))
	_expect("NEW_reuse_bare/vanished", not is_instance_valid(a) or a._expired)
	_expect("NEW_reuse_bare/no_leftovers", HitboxArea.count_active(o) == 0)


func _t_out_of_range() -> void:
	var o := _owner_plain()
	var t := _target(Vector2(300, 0))
	await _phys(2)
	var d := _def()
	d.duration_frames = 4
	HitboxArea.spawn(d, o)
	await _phys(8)
	_expect("NEW_no_hit/out_of_range", t.received.is_empty(), "hits=%d" % t.received.size())


func _t_mask() -> void:
	var o := _owner_plain()
	var wrong_layer := _target(Vector2.ZERO, 8)
	await _phys(2)
	var d := _def()
	d.duration_frames = 4
	HitboxArea.spawn(d, o)
	await _phys(8)
	_expect("NEW_mask/other_layer_ignored", wrong_layer.received.is_empty(), "hits=%d" % wrong_layer.received.size())


func _t_one_hit() -> void:
	var o := _owner_plain()
	var t := _target()
	await _phys(2)
	var d := _def()
	d.duration_frames = 8
	HitboxArea.spawn(d, o)
	await _phys(16)
	_expect("NEW_one_hit/while_target_stays_inside", t.received.size() == 1, "hits=%d" % t.received.size())


func _t_lifetime() -> void:
	var o := _owner_plain()
	for frames in [1, 3, 6]:
		var d := _def()
		d.duration_frames = frames
		var a := HitboxArea.spawn(d, o)
		var ticks := await _ticks_until_gone(a)
		_expect("NEW_lifetime/duration_%d_lasts_at_least_%d_ticks" % [frames, frames], ticks >= frames and ticks <= frames + 3,
			"ticks=%d" % ticks)


func _t_growth() -> void:
	var o := _owner_plain(Vector2(100, 50))
	var d := _def(Vector2(10, 10))
	d.grow_per_frame = Vector2(10, 0)
	d.grow_anchor = Vector2(0, 0.5)
	d.offset = Vector2(5, 0)
	d.duration_frames = 0
	var a := HitboxArea.spawn(d, o)
	_expect("NEW_growth/starts_at_base_size", _near(a._shape.size.x, 10.0), str(a._shape.size))
	await _phys(3)
	var s1: float = a._shape.size.x
	var e1: float = _left_edge(a)
	await _phys(3)
	var s2: float = a._shape.size.x
	var e2: float = _left_edge(a)
	_expect("NEW_growth/grows_10px_per_frame", _near(s2 - s1, 30.0), "s1=%s s2=%s" % [str(s1), str(s2)])
	_expect("NEW_growth/back_edge_stays_fixed", _near(e1, 5.0) and _near(e2, 5.0), "e1=%s e2=%s" % [str(e1), str(e2)])
	_expect("NEW_growth/height_untouched", _near(a._shape.size.y, 10.0))
	HitboxArea.clear(o)


func _t_max_cap() -> void:
	var o := _owner_plain()
	var d := _def(Vector2(10, 10))
	d.grow_per_frame = Vector2(10, 10)
	d.max_size = Vector2(35, 0)   # teto só no X
	d.duration_frames = 0
	var a := HitboxArea.spawn(d, o)
	await _phys(12)
	_expect("NEW_cap/x_capped", _near(a._shape.size.x, 35.0), str(a._shape.size))
	_expect("NEW_cap/y_uncapped_keeps_growing", a._shape.size.y > 35.0, str(a._shape.size))
	HitboxArea.clear(o)


func _t_min_floor() -> void:
	var o := _owner_plain()
	var d := _def(Vector2(5, 5))
	d.grow_per_frame = Vector2(-3, -3)   # 5, 2, -1...: só o piso de 1 px segura o resultado
	d.duration_frames = 0
	var a := HitboxArea.spawn(d, o)
	await _phys(8)
	_expect("NEW_floor/never_below_1px", _near(a._shape.size.x, 1.0) and _near(a._shape.size.y, 1.0), str(a._shape.size))
	HitboxArea.clear(o)


func _t_follows() -> void:
	var o := _owner_plain(Vector2.ZERO)
	var d := _def()
	d.duration_frames = 0
	var a := HitboxArea.spawn(d, o)
	await _phys(2)
	o.position = Vector2(50, 0)
	await _phys(1)
	_expect("NEW_follows/hitbox_moves_with_owner", _near(a.global_position.x, 50.0), "x=%s" % str(a.global_position.x))
	HitboxArea.clear(o)


func _t_mirror() -> void:
	var o := _owner_flip()
	var d := _def(Vector2(10, 10))
	d.offset = Vector2(5, 0)
	d.grow_anchor = Vector2(0, 0.5)
	d.duration_frames = 0
	var a := HitboxArea.spawn(d, o)
	await _phys(2)
	_expect("NEW_mirror/facing_right_extends_forward", _near(_left_edge(a), 5.0) and a._col.position.x > 5.0,
		"left=%s cx=%s" % [str(_left_edge(a)), str(a._col.position.x)])
	o.flip = -1
	await _phys(2)
	_expect("NEW_mirror/facing_left_mirrors_x", _near(_right_edge(a), -5.0) and a._col.position.x < -5.0,
		"right=%s cx=%s" % [str(_right_edge(a)), str(a._col.position.x)])
	HitboxArea.clear(o)


func _t_clear() -> void:
	var o := _owner_plain()
	var tok_a := Node.new()
	var tok_b := Node.new()
	_track(tok_a)
	_track(tok_b)
	var d_a := _def()
	d_a.duration_frames = 0
	var d_b := _def()
	d_b.duration_frames = 0
	var d_c := _def()
	d_c.duration_frames = 0
	d_c.id = &"main"
	HitboxArea.spawn(d_a, o, tok_a)
	HitboxArea.spawn(d_b, o, tok_b)
	HitboxArea.spawn(d_c, o, tok_b)
	_expect("NEW_clear/three_active", HitboxArea.count_active(o) == 3)
	_expect("NEW_clear/count_by_token", HitboxArea.count_active(o, tok_b) == 2)
	_expect("NEW_clear/by_token_removes_only_its_own", HitboxArea.clear(o, tok_a) == 1 and HitboxArea.count_active(o, tok_b) == 2)
	_expect("NEW_clear/idempotent", HitboxArea.clear(o, tok_a) == 0)
	_expect("NEW_clear/by_id_inside_token", HitboxArea.clear(o, tok_b, &"main") == 1 and HitboxArea.count_active(o) == 1)
	_expect("NEW_clear/all_for_owner", HitboxArea.clear(o) == 1 and HitboxArea.count_active(o) == 0)
	await _phys(2)
	var leftovers: int = 0
	for c in o.get_children():
		if c is HitboxArea:
			leftovers += 1
	_expect("NEW_clear/nodes_freed", leftovers == 0, "restaram=%d" % leftovers)


func _t_safety() -> void:
	var o := _owner_plain()
	var d := _def()
	d.duration_frames = 0
	d.safety_timeout = 0.1
	var a := HitboxArea.spawn(d, o)
	await _phys(20)   # ~0,33 s
	_expect("NEW_safety/expires_without_clear", _is_gone(a) and HitboxArea.count_active(o) == 0)


func _t_frame_source() -> void:
	var o := _owner_plain()
	var sp := _sprite("a", 6)
	var d := _def(Vector2(10, 10))
	d.grow_per_frame = Vector2(4, 0)
	d.duration_frames = 2
	var a := HitboxArea.spawn(d, o, null, sp)
	await _phys(6)   # o tempo passa, mas o frame da animação não mudou
	_expect("NEW_frame_source/time_alone_does_not_advance", not _is_gone(a) and _near(a._shape.size.x, 10.0),
		"gone=%s" % str(_is_gone(a)))
	sp.frame = 1
	await _phys(2)
	_expect("NEW_frame_source/one_animation_frame_one_step", not _is_gone(a) and _near(a._shape.size.x, 14.0),
		"gone=%s" % str(_is_gone(a)))
	sp.frame = 2
	await _phys(2)
	_expect("NEW_frame_source/expires_after_duration_frames", _is_gone(a))


func _t_anim_change() -> void:
	var o := _owner_plain()
	var sp := _sprite("a", 6)
	var d := _def()
	d.duration_frames = 0
	var a := HitboxArea.spawn(d, o, null, sp)
	await _phys(4)
	_expect("NEW_anim_change/alive_while_same_animation", not _is_gone(a))
	sp.animation = "b"
	await _phys(3)
	_expect("NEW_anim_change/expires_when_animation_changes", _is_gone(a))


func _t_shared_def() -> void:
	var d := _def()
	d.duration_frames = 4
	var o1 := _owner_plain(Vector2(0, 0))
	var o2 := _owner_plain(Vector2(500, 0))
	var t1 := _target(Vector2(0, 0))
	var t2 := _target(Vector2(500, 0))
	await _phys(2)
	var a1 := HitboxArea.spawn(d, o1)
	var a2 := HitboxArea.spawn(d, o2)
	_expect("NEW_shared/independent_shapes", a1._shape != a2._shape)
	await _phys(8)
	_expect("NEW_shared/each_owner_hits_its_own_target", t1.received.size() == 1 and t2.received.size() == 1,
		"t1=%d t2=%d" % [t1.received.size(), t2.received.size()])


func _t_owner_freed() -> void:
	var o := _owner_plain()
	var d := _def()
	d.duration_frames = 0
	var a := HitboxArea.spawn(d, o)
	o.queue_free()
	await _phys(3)
	_expect("NEW_owner_freed/hitbox_gone_with_owner", not is_instance_valid(a))


# ============================================================
# Saída
# ============================================================

func _finish() -> void:
	var path := "user://hitbox_core_%s.txt" % label
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	print("")
	print("HITBOX core [%s]" % label)
	print("HITBOX core — log: %s" % ProjectSettings.globalize_path(path))
	print("HITBOX core — ASSERT: PASS=%d FAIL=%d" % [_pass, _fail])
