extends Node2D
## [A1 · VALIDAÇÃO TEMPORÁRIA — remover na A1.3]
##
## Harness de baseline e de testes da A1 (offset e follow do ParticleFX).
##
## COMO USAR
##   1. Abra _a1_validation/A1Baseline.tscn e rode a cena (F6).
##   2. O resultado aparece no Output e em user://a1_<label>.txt (o caminho é impresso).
##   3. BASELINE: rode ANTES de aplicar qualquer mudança da A1 (label = "baseline").
##      DEPOIS de cada etapa: mude o label no Inspector (ex.: "a1_1") e rode de novo.
##      O harness compara sozinho os cenários [REG] com o baseline e imprime o diff.
##
## O QUE ELE FAZ
##   [REG]  cenários de regressão: o log precisa ser IDÊNTICO ao baseline.
##   [NEW]  cenários do recurso novo, com expectativa calculada aqui dentro
##          (ASSERT PASS/FAIL). No baseline eles falham de propósito (o recurso ainda não existe).
##
## Determinismo: seed() fixo por cenário; spawns dirigidos por tempo logam só os primeiros N
## (a contagem total varia com o framerate, a sequência não). sprite_frames é substituído por
## um mínimo gerado em código — a posição não depende da arte. Defs reais (.tres) são usadas
## quando carregam; senão entram defs sintéticas com os mesmos parâmetros de posição.

@export var label: String = "baseline"

const SEED_VALUE: int = 1234
const POS_EPS: float = 0.01
const BASELINE_LABEL: String = "baseline"

## Dono com espelhamento por orientação nativa (como o Boss).
class FakeBoss extends Node2D:
	var facing_right: bool = true
	var native_facing_right: bool = true
	func get_facing_flip() -> int:
		return -1 if facing_right != native_facing_right else 1

## Dono sem get_facing_flip (como o Player).
class FakePlayer extends Node2D:
	var facing_right: bool = true

var _frames: SpriteFrames
var _actors: Array[Node] = []

var _sid: String = ""
var _tag: String = ""
var _max_log: int = 12
var _logged: int = 0
var _spawns: Array[Dictionary] = []
var _lines: PackedStringArray = []
var _order: Array[String] = []
var _groups: Dictionary = {}   # sid -> {"tag": String, "lines": PackedStringArray}
var _pass: int = 0
var _fail: int = 0
var _real_used: Array[String] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("label="):
			label = a.substr(6)
	_frames = _make_frames(["default"])
	Engine.set_meta(&"a1_spawn_log", Callable(self, "_on_instance_setup"))
	await get_tree().process_frame
	await _run_all()
	if Engine.has_meta(&"a1_spawn_log"):
		Engine.remove_meta(&"a1_spawn_log")
	_finish()
	get_tree().quit()


# ============================================================
# Infra
# ============================================================

func _make_frames(anim_names: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	for n in anim_names:
		if not sf.has_animation(n):
			sf.add_animation(n)
		sf.add_frame(n, tex)
	return sf


func _sdef(def_name: String, p: Dictionary = {}) -> SpawnedParticleDef:
	var d := SpawnedParticleDef.new()
	d.sprite_frames = _frames
	d.animations = ["default"]
	d.lifetime = 0.30
	d.lifetime_variance = 0.0
	d.velocity_min = 0.0
	d.velocity_max = 0.0
	d.spread_angle = 0.0
	d.fade_out = false
	for k in p:
		d.set(k, p[k])
	d.set_meta(&"a1_name", def_name)
	return d


## Def real (.tres) com a arte trocada por frames mínimos e SFX mudo; null se não carregar.
func _prep_real(res: Resource, def_name: String) -> SpawnedParticleDef:
	if res == null or not (res is SpawnedParticleDef):
		return null
	var d: SpawnedParticleDef = (res as SpawnedParticleDef).duplicate()
	var names: Array = ["default"]
	for a in d.animations:
		names.append(a)
	d.sprite_frames = _make_frames(names)
	d.play_sfx = false
	d.set_meta(&"a1_name", def_name)
	_real_used.append(def_name)
	return d


func _load_real(path: String, def_name: String) -> SpawnedParticleDef:
	if not ResourceLoader.exists(path):
		return null
	return _prep_real(load(path), def_name)


func _load_preamble() -> SpawnedParticleDef:
	var path := "res://enemies/boss/characters/magma_dragoon/BehaviorTree/Actions/AnimPhase/MeteorFall_AnimPhase.tres"
	if not ResourceLoader.exists(path):
		return null
	var ph = load(path)
	if ph == null:
		return null
	for ev in ph.frame_events:
		if ev != null and ev.fx_resource is BarrageDef and ev.fx_resource.preamble_fx != null:
			return _prep_real(ev.fx_resource.preamble_fx, "meteor_preamble")
	return null


func _mk_boss(pos: Vector2, native_right: bool, facing_right: bool, markers: Dictionary = {}) -> FakeBoss:
	var b := FakeBoss.new()
	b.name = "FakeBoss"
	b.native_facing_right = native_right
	b.facing_right = facing_right
	add_child(b)
	b.global_position = pos
	for m in markers:
		var mk := Marker2D.new()
		mk.name = m
		mk.position = markers[m]
		b.add_child(mk)
	_actors.append(b)
	return b


func _mk_player(pos: Vector2, facing_right: bool, markers: Dictionary = {}) -> FakePlayer:
	var p := FakePlayer.new()
	p.name = "FakePlayer"
	p.facing_right = facing_right
	add_child(p)
	p.global_position = pos
	for m in markers:
		var mk := Marker2D.new()
		mk.name = m
		mk.position = markers[m]
		p.add_child(mk)
	_actors.append(p)
	return p


func _mk_plain(pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.name = "PlainOwner"
	add_child(n)
	n.global_position = pos
	_actors.append(n)
	return n


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _clean() -> void:
	for a in _actors:
		if is_instance_valid(a):
			a.queue_free()
	_actors.clear()
	var fx := get_node_or_null("FXContainer")
	if fx:
		for c in fx.get_children():
			c.queue_free()


func _emit(line: String) -> void:
	_lines.append(line)
	if _groups.has(_sid):
		(_groups[_sid]["lines"] as PackedStringArray).append(line)


## Gancho chamado pelo ParticleInstance.setup() (temporário).
func _on_instance_setup(inst: Node2D, def: Resource, owner: Node2D) -> void:
	var spr = inst.get("_sprite")
	var flip: bool = spr.flip_h if spr != null else false
	var dname: String = String(def.get_meta(&"a1_name", "?"))
	_spawns.append({"pos": inst.global_position, "flip": flip, "node": inst, "def": dname,
		"opos": owner.global_position if owner else Vector2(INF, INF)})
	_logged += 1
	if _logged <= _max_log:
		_emit("SPAWN|def=%s|owner=%s|pos=(%.3f,%.3f)|z=%d|flip_h=%s" % [
			dname, owner.name if owner else "none",
			inst.global_position.x, inst.global_position.y, inst.z_index, str(flip)])


func _scenario(sid: String, tag: String, body: Callable, tail_s: float = 0.2, max_log: int = 12) -> void:
	_sid = sid
	_tag = tag
	_max_log = max_log
	_logged = 0
	_spawns.clear()
	_order.append(sid)
	_groups[sid] = {"tag": tag, "lines": PackedStringArray()}
	_lines.append("=== %s [%s] ===" % [sid, tag])
	seed(SEED_VALUE)
	await body.call()
	await _wait(tail_s)
	ParticleFX.stop_all_continuous()
	_clean()
	await get_tree().process_frame


func _expect(test_name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
	var line := "ASSERT|%s|%s|%s" % [test_name, "PASS" if cond else "FAIL", detail]
	_lines.append(line)
	print(line)


func _expect_pos(test_name: String, got: Vector2, want: Vector2) -> void:
	_expect(test_name, got.distance_to(want) <= POS_EPS, "got=%s want=%s" % [str(got), str(want)])


func _last_pos() -> Vector2:
	return _spawns.back()["pos"] if not _spawns.is_empty() else Vector2(INF, INF)


# ============================================================
# Cenários
# ============================================================

func _run_all() -> void:
	# ---------------- REGRESSÃO (devem ser idênticos ao baseline) ----------------
	await _scenario("REG_player_spark_right", "REG", func() -> void: _reg_spark(true))
	await _scenario("REG_player_spark_left", "REG", func() -> void: _reg_spark(false))
	await _scenario("REG_player_smoke_spawner", "REG", _reg_smoke, 0.1, 3)
	for native_right in [false, true]:
		for facing_right in [false, true]:
			var nm := "REG_preamble_native%s_face%s" % ["R" if native_right else "L", "R" if facing_right else "L"]
			await _scenario(nm, "REG", func() -> void: await _reg_preamble(native_right, facing_right), 0.1, 3)
	await _scenario("REG_explosion_wave", "REG", _reg_explosion, 0.1, 6)
	await _scenario("REG_death_burst_delay_noowner", "REG", _reg_death)
	await _scenario("REG_burst_basic", "REG", _reg_burst_basic)
	await _scenario("REG_burst_interval", "REG", _reg_burst_interval, 0.2)
	await _scenario("REG_variance", "REG", _reg_variance)
	await _scenario("REG_delay_noowner", "REG", _reg_delay_noowner, 0.2)
	await _scenario("REG_delay_owner_plain_captured_at_call", "REG", _reg_delay_owner_plain, 0.2)
	await _scenario("REG_spawn_exact", "REG", _reg_spawn_exact)

	# ---------------- RECURSO NOVO: offset (A1.1) ----------------
	var off := Vector2(-20, -8)
	await _scenario("NEW_offset_nativeL_faceL_mirror", "NEW", func() -> void: _new_offset(false, false, true, off, Vector2(80, 92)))
	await _scenario("NEW_offset_nativeL_faceR_mirror", "NEW", func() -> void: _new_offset(false, true, true, off, Vector2(120, 92)))
	await _scenario("NEW_offset_nativeL_faceR_nomirror", "NEW", func() -> void: _new_offset(false, true, false, off, Vector2(80, 92)))
	await _scenario("NEW_offset_nativeR_faceR_mirror", "NEW", func() -> void: _new_offset(true, true, true, off, Vector2(80, 92)))
	await _scenario("NEW_offset_nativeR_faceL_mirror", "NEW", func() -> void: _new_offset(true, false, true, off, Vector2(120, 92)))
	await _scenario("NEW_offset_with_marker", "NEW", _new_offset_marker)
	await _scenario("NEW_offset_existing_node_Sprite", "NEW", _new_offset_sprite_node)
	await _scenario("NEW_offset_owner_null_ignored", "NEW", _new_offset_owner_null)
	await _scenario("NEW_art_vs_position_independent", "NEW", _new_art_vs_position)
	await _scenario("NEW_offset_follow_false_independent", "NEW", _new_offset_independent, 0.1)
	await _scenario("NEW_burst_interval_offset_once", "NEW", _new_burst_interval_offset, 0.2)
	await _scenario("NEW_burst_interval_follow_true_offset_once", "NEW", _new_burst_follow_offset, 0.2)
	await _scenario("NEW_wave_offset_once", "NEW", _new_wave_offset, 0.1, 6)

	# ---------------- RECURSO NOVO: spawn_delay sem teleporte (A1.1) ----------------
	await _scenario("NEW_delay_marker_resolved_at_fire", "NEW", _new_delay_marker, 0.1)
	await _scenario("NEW_delay_offset_resolved_at_fire", "NEW", _new_delay_offset, 0.1)
	await _scenario("NEW_delay_owner_freed_falls_back", "NEW", _new_delay_owner_freed, 0.1)
	await _scenario("NEW_wave_delay_resolved_at_fire", "NEW", _new_wave_delay, 0.1, 6)

	# ---------------- RECURSO NOVO: follow (A1.2) ----------------
	await _scenario("NEW_follow_nomarker_constant", "NEW", _new_follow_const, 0.1)
	await _scenario("NEW_follow_turn_remirrors_same_frame", "NEW", _new_follow_turn, 0.1)
	await _scenario("NEW_follow_mirror_off_ignores_turn", "NEW", _new_follow_mirror_off, 0.1)
	await _scenario("NEW_follow_native_right_boss_turn", "NEW", _new_follow_native_right, 0.1)
	await _scenario("NEW_follow_player_like_no_flip_method", "NEW", _new_follow_player_like, 0.1)
	await _scenario("NEW_follow_with_marker_animated", "NEW", _new_follow_marker, 0.1)
	await _scenario("NEW_follow_existing_node_Sprite", "NEW", _new_follow_sprite_node, 0.1)
	await _scenario("NEW_follow_variance_preserved", "NEW", _new_follow_variance, 0.1)
	await _scenario("NEW_follow_burst_between_steps_follows_owner", "NEW", _new_follow_burst_steps, 0.1)
	await _scenario("NEW_follow_delay_no_teleport", "NEW", _new_follow_delay, 0.1)
	await _scenario("NEW_follow_owner_freed_keeps_fading", "NEW", _new_follow_owner_freed, 0.1)
	await _scenario("NEW_follow_marker_freed_stops_following", "NEW", _new_follow_marker_freed, 0.1)
	await _scenario("NEW_follow_ignores_own_velocity", "NEW", _new_follow_ignores_velocity, 0.1)
	await _scenario("NEW_follow_false_still_moves_by_velocity", "NEW", _new_follow_false_moves, 0.1)

	# ---------------- RECURSO NOVO: rotação espelhada com o facing + follow_updates_facing ----------------
	await _scenario("NEW_rot_flags_off_unchanged", "NEW", _new_rot_flags_off, 0.1)
	await _scenario("NEW_rot_mirror_fixed", "NEW", _new_rot_mirror_fixed, 0.1)
	await _scenario("NEW_rot_mirror_is_exact_reflection", "NEW", _new_rot_exact_reflection, 0.1)
	await _scenario("NEW_rot_mirror_needs_inherit_facing", "NEW", _new_rot_needs_inherit, 0.1)
	await _scenario("NEW_rot_owner_without_facing_right", "NEW", _new_rot_owner_without_facing, 0.1)
	await _scenario("NEW_rot_follow_turn_remirrors", "NEW", _new_rot_follow_turn, 0.1)
	await _scenario("NEW_rot_follow_turn_flag_off_decided_at_birth", "NEW", _new_rot_follow_flag_off, 0.1)
	await _scenario("NEW_rot_follow_updates_art_only", "NEW", _new_rot_follow_art_only, 0.1)
	await _scenario("NEW_rot_follow_updates_needs_follow", "NEW", _new_rot_updates_needs_follow, 0.1)
	await _scenario("NEW_rot_follow_updates_needs_inherit_facing", "NEW", _new_rot_updates_needs_inherit, 0.1)
	await _scenario("NEW_rot_follow_owner_freed_no_error", "NEW", _new_rot_follow_owner_freed, 0.1)
	await _scenario("NEW_rot_firekick_like", "NEW", _new_rot_firekick_like, 0.1)


# ---------------- REG ----------------

func _reg_spark(facing_right: bool) -> void:
	var p := _mk_player(Vector2(100, 200), facing_right, {"DashSpark": Vector2(-6, 14)})
	var d := _load_real("res://particlesystem/resources/FX/dash_spark_def.tres", "dash_spark")
	if d == null:
		d = _sdef("dash_spark", {"marker_path": "DashSpark", "inherit_facing": true})
	ParticleFX.spawn_at(d, Vector2.ZERO, Vector2.ZERO, p)


func _reg_smoke() -> void:
	var p := _mk_player(Vector2(100, 200), true, {"DashSpark": Vector2(-6, 14)})
	var d := _load_real("res://particlesystem/resources/FX/dash_smoke_def.tres", "dash_smoke")
	if d == null:
		d = _sdef("dash_smoke", {"marker_path": "DashSpark", "offset": Vector2(0, 12),
			"repeat_interval": 0.08, "spawn_delay": 0.1, "inherit_facing": true})
	var marker: Node2D = p.get_node(d.marker_path)
	var sp := ParticleFX.create_spawner(d, marker, d.offset)
	sp.owner_node = p
	sp.interval = d.repeat_interval
	sp.start()
	await _wait(0.35)
	sp.queue_free()


func _reg_preamble(native_right: bool, facing_right: bool) -> void:
	var b := _mk_boss(Vector2(100, 100), native_right, facing_right, {"FireBlastEffect": Vector2(8, -10)})
	var d := _load_preamble()
	if d == null:
		d = _sdef("meteor_preamble", {"marker_path": "FireBlastEffect", "mirror_marker_with_facing": true,
			"position_variance": Vector2(8, 0), "repeat_interval": 0.08})
	var anchor := ParticleFX.spawn_continuous(d, b.global_position, b)
	await _wait(0.4)
	if is_instance_valid(anchor):
		anchor.queue_free()


func _reg_explosion() -> void:
	var o := _mk_plain(Vector2(300, 120))
	var d := _load_real("res://enemies/boss/characters/magma_dragoon/cutscene/defeat/Explosion_SpawnParticle_FX_Def.tres", "explosion")
	if d == null:
		d = _sdef("explosion", {"wave": true, "repeat_interval": 0.2, "spawn_interval": 0.1,
			"burst_count": 3, "position_variance": Vector2(10, 5)})
	ParticleFX.spawn_at(d, o.global_position + Vector2(0, -10), Vector2.ZERO, o)
	await _wait(0.9)


func _reg_death() -> void:
	var d := _sdef("death_burst", {"spawn_delay": 0.5, "burst_count": 8, "even_spread": true,
		"spread_angle": 360.0, "velocity_min": 40.0, "velocity_max": 40.0})
	ParticleFX.spawn_at(d, Vector2(400, 300))
	await _wait(0.8)


func _reg_burst_basic() -> void:
	var d := _sdef("burst_basic", {"burst_count": 5, "spread_angle": 90.0, "velocity_min": 10.0, "velocity_max": 30.0})
	ParticleFX.spawn_at(d, Vector2(50, 50))


func _reg_burst_interval() -> void:
	var d := _sdef("burst_interval", {"burst_count": 4, "spawn_interval": 0.1})
	ParticleFX.spawn_at(d, Vector2(60, 60))
	await _wait(0.5)


func _reg_variance() -> void:
	var d := _sdef("variance", {"burst_count": 6, "position_variance": Vector2(10, 5)})
	ParticleFX.spawn_at(d, Vector2(70, 70))


func _reg_delay_noowner() -> void:
	var d := _sdef("delay_noowner", {"spawn_delay": 0.3})
	ParticleFX.spawn_at(d, Vector2(80, 80))
	await _wait(0.5)


## Dono + atraso, mas SEM marker/offset/follow: a posição continua sendo a de quando foi chamado.
func _reg_delay_owner_plain() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("delay_owner_plain", {"spawn_delay": 0.3})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	await _wait(0.1)
	b.global_position = Vector2(160, 100)
	await _wait(0.4)


func _reg_spawn_exact() -> void:
	var d := _sdef("spawn_exact")
	ParticleFX.spawn_exact(d, Vector2(90, 90), Vector2.RIGHT, 20.0, 0.3)


# ---------------- NEW: offset ----------------

func _new_offset(native_right: bool, facing_right: bool, mirror: bool, off: Vector2, want: Vector2) -> void:
	var b := _mk_boss(Vector2(100, 100), native_right, facing_right)
	var d := _sdef("offset", {"offset": off, "mirror_marker_with_facing": mirror})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	_expect_pos(_sid, _last_pos(), want)


## Boss nativo-esquerda olhando para a direita (flip = -1). Marker em (10,-5) -> espelhado (-10,-5).
func _new_offset_marker() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true, {"M": Vector2(10, -5)})
	var d := _sdef("offset_marker", {"marker_path": "M", "offset": Vector2(-20, -8), "mirror_marker_with_facing": true})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	_expect_pos(_sid, _last_pos(), Vector2(110, 87))


## Âncora = nó que já existe na cena (sem criar Marker2D novo).
func _new_offset_sprite_node() -> void:
	var b := _mk_boss(Vector2(100, 100), false, false)
	var s := Node2D.new()
	s.name = "Sprite"
	s.position = Vector2(4, -6)
	b.add_child(s)
	var d := _sdef("offset_sprite", {"marker_path": "Sprite", "offset": Vector2(0, -10)})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	_expect_pos(_sid, _last_pos(), Vector2(104, 84))


## Sem dono não há referência: convenção "owner = null -> posição já final".
func _new_offset_owner_null() -> void:
	var d := _sdef("offset_null", {"offset": Vector2(-20, -8), "mirror_marker_with_facing": true})
	ParticleFX.spawn_at(d, Vector2(50, 50), Vector2.ZERO, null)
	_expect_pos(_sid, _last_pos(), Vector2(50, 50))


## Espelhar a POSIÇÃO e espelhar a ARTE são comportamentos independentes.
func _new_art_vs_position() -> void:
	var off := Vector2(-20, 0)
	# A: só a arte (inherit_facing). A posição NÃO muda com o lado.
	var b1 := _mk_boss(Vector2(100, 100), false, true)
	ParticleFX.spawn_at(_sdef("art_only", {"offset": off, "mirror_marker_with_facing": false, "inherit_facing": true}), b1.global_position, Vector2.ZERO, b1)
	var a_right: Dictionary = _spawns.back()
	b1.facing_right = false
	ParticleFX.spawn_at(_sdef("art_only", {"offset": off, "mirror_marker_with_facing": false, "inherit_facing": true}), b1.global_position, Vector2.ZERO, b1)
	var a_left: Dictionary = _spawns.back()
	_expect(_sid + "/art_only_position_same", (a_right["pos"] as Vector2).distance_to(a_left["pos"]) <= POS_EPS and (a_right["pos"] as Vector2).distance_to(Vector2(80, 100)) <= POS_EPS, "right=%s left=%s" % [str(a_right["pos"]), str(a_left["pos"])])
	_expect(_sid + "/art_only_flip_differs", a_right["flip"] != a_left["flip"], "right=%s left=%s" % [str(a_right["flip"]), str(a_left["flip"])])
	# B: só a posição (mirror). A arte NÃO espelha.
	var b2 := _mk_boss(Vector2(100, 100), false, true)
	ParticleFX.spawn_at(_sdef("pos_only", {"offset": off, "mirror_marker_with_facing": true, "inherit_facing": false}), b2.global_position, Vector2.ZERO, b2)
	var p_right: Dictionary = _spawns.back()
	b2.facing_right = false
	ParticleFX.spawn_at(_sdef("pos_only", {"offset": off, "mirror_marker_with_facing": true, "inherit_facing": false}), b2.global_position, Vector2.ZERO, b2)
	var p_left: Dictionary = _spawns.back()
	_expect(_sid + "/pos_only_position_differs", (p_right["pos"] as Vector2).distance_to(p_left["pos"]) > 1.0, "right=%s left=%s" % [str(p_right["pos"]), str(p_left["pos"])])
	_expect(_sid + "/pos_only_flip_same", p_right["flip"] == p_left["flip"] and p_right["flip"] == false, "right=%s left=%s" % [str(p_right["flip"]), str(p_left["flip"])])


## follow = false: nasce relativo ao dono e depois fica independente.
func _new_offset_independent() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("offset_indep", {"offset": Vector2(-20, -8), "mirror_marker_with_facing": true, "lifetime": 1.0})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	var born := _last_pos()
	_expect_pos(_sid + "/born", born, Vector2(120, 92))
	var inst: Node2D = _spawns.back()["node"]
	b.global_position = Vector2(200, 100)
	await _wait(0.2)
	_expect_pos(_sid + "/stays", inst.global_position, Vector2(120, 92))


func _new_burst_interval_offset() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("burst_offset", {"burst_count": 3, "spawn_interval": 0.1, "offset": Vector2(-20, -8), "mirror_marker_with_facing": true})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	await _wait(0.35)
	_expect(_sid + "/count", _spawns.size() == 3, "n=%d" % _spawns.size())
	for i in _spawns.size():
		_expect_pos("%s/step%d" % [_sid, i], _spawns[i]["pos"], Vector2(120, 92))


## Garante que o re-resolve do follow no burst não soma o offset de novo.
func _new_burst_follow_offset() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("burst_follow_offset", {"burst_count": 3, "spawn_interval": 0.1, "follow_marker": true,
		"offset": Vector2(-20, -8), "mirror_marker_with_facing": true})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	await _wait(0.35)
	_expect(_sid + "/count", _spawns.size() == 3, "n=%d" % _spawns.size())
	for i in _spawns.size():
		_expect_pos("%s/step%d" % [_sid, i], _spawns[i]["pos"], Vector2(120, 92))


func _new_wave_offset() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("wave_offset", {"wave": true, "repeat_interval": 0.1, "repeat_duration": 0.35,
		"offset": Vector2(-20, -8), "mirror_marker_with_facing": true})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	await _wait(0.4)
	_expect(_sid + "/has_spawns", _spawns.size() >= 3, "n=%d" % _spawns.size())
	for i in mini(_spawns.size(), 3):
		_expect_pos("%s/wave%d" % [_sid, i], _spawns[i]["pos"], Vector2(120, 92))


# ---------------- NEW: spawn_delay sem teleporte ----------------

## O Boss anda durante o atraso. O FX nasce UMA vez, já na posição final.
func _new_delay_marker() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true, {"M": Vector2(10, -5)})
	var d := _sdef("delay_marker", {"marker_path": "M", "offset": Vector2(-20, -8),
		"mirror_marker_with_facing": true, "spawn_delay": 0.3})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	await _wait(0.1)
	b.global_position = Vector2(160, 100)
	await _wait(0.4)
	_expect(_sid + "/single_birth", _spawns.size() == 1, "n=%d" % _spawns.size())
	_expect_pos(_sid + "/pos", _last_pos(), Vector2(170, 87))


func _new_delay_offset() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("delay_offset", {"offset": Vector2(-20, -8), "mirror_marker_with_facing": true, "spawn_delay": 0.3})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	await _wait(0.1)
	b.global_position = Vector2(160, 100)
	await _wait(0.4)
	_expect(_sid + "/single_birth", _spawns.size() == 1, "n=%d" % _spawns.size())
	_expect_pos(_sid + "/pos", _last_pos(), Vector2(180, 92))


## Dono liberado durante o atraso: cai na posição resolvida quando foi chamado (sem erro).
func _new_delay_owner_freed() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("delay_freed", {"offset": Vector2(-20, -8), "mirror_marker_with_facing": true, "spawn_delay": 0.3})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	await _wait(0.1)
	b.free()
	_actors.erase(b)
	await _wait(0.4)
	_expect(_sid + "/single_birth", _spawns.size() == 1, "n=%d" % _spawns.size())
	_expect_pos(_sid + "/pos", _last_pos(), Vector2(120, 92))


func _new_wave_delay() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("wave_delay", {"wave": true, "repeat_interval": 0.1, "repeat_duration": 0.25,
		"offset": Vector2(-20, -8), "mirror_marker_with_facing": true, "spawn_delay": 0.3})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	await _wait(0.1)
	b.global_position = Vector2(160, 100)
	await _wait(0.6)
	_expect(_sid + "/has_spawns", _spawns.size() >= 2, "n=%d" % _spawns.size())
	for i in mini(_spawns.size(), 2):
		_expect_pos("%s/wave%d" % [_sid, i], _spawns[i]["pos"], Vector2(180, 92))


# ---------------- NEW: follow ----------------

func _two_frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _disp(inst: Node2D, owner_node: Node2D) -> Vector2:
	return inst.global_position - owner_node.global_position


func _move_and_settle(n: Node2D, to: Vector2) -> void:
	n.global_position = to
	await _two_frames()


func _spawn_follow(native_right: bool, facing_right: bool, props: Dictionary, markers: Dictionary = {}) -> Array:
	var b := _mk_boss(Vector2(100, 100), native_right, facing_right, markers)
	var d := _sdef("follow", props)
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	return [b, _spawns.back()["node"]]


## Move o dono por vários passos e devolve o maior desvio do deslocamento esperado.
func _drift(b: Node2D, inst: Node2D, want: Vector2, steps: int = 8) -> float:
	var worst := 0.0
	for i in steps:
		await _move_and_settle(b, b.global_position + Vector2(10, 3))
		worst = maxf(worst, _disp(inst, b).distance_to(want))
	return worst


func _new_follow_const() -> void:
	var r := _spawn_follow(false, true, {"follow_marker": true, "offset": Vector2(-20, -8),
		"mirror_marker_with_facing": true, "lifetime": 3.0})
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	_expect_pos(_sid + "/born", _disp(inst, b), Vector2(20, -8))
	var worst: float = await _drift(b, inst, Vector2(20, -8))
	_expect(_sid + "/constant_while_owner_moves", worst <= POS_EPS, "desvio_max=%.4f" % worst)


## Virada do dono no meio da vida: o deslocamento é re-espelhado no mesmo frame.
func _new_follow_turn() -> void:
	var r := _spawn_follow(false, true, {"follow_marker": true, "offset": Vector2(-20, -8),
		"mirror_marker_with_facing": true, "lifetime": 3.0})
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	var w1: float = await _drift(b, inst, Vector2(20, -8), 3)
	b.facing_right = false
	await _two_frames()
	_expect_pos(_sid + "/after_turn", _disp(inst, b), Vector2(-20, -8))
	var w2: float = await _drift(b, inst, Vector2(-20, -8), 3)
	_expect(_sid + "/constant_before_and_after", w1 <= POS_EPS and w2 <= POS_EPS, "w1=%.4f w2=%.4f" % [w1, w2])


## Sem a flag de espelho a posição não muda com a virada (e o dono continua sendo seguido).
func _new_follow_mirror_off() -> void:
	var r := _spawn_follow(false, true, {"follow_marker": true, "offset": Vector2(-20, -8),
		"mirror_marker_with_facing": false, "lifetime": 3.0})
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	var w1: float = await _drift(b, inst, Vector2(-20, -8), 3)
	b.facing_right = false
	await _two_frames()
	var w2: float = await _drift(b, inst, Vector2(-20, -8), 3)
	_expect(_sid + "/unmirrored_and_following", w1 <= POS_EPS and w2 <= POS_EPS, "w1=%.4f w2=%.4f" % [w1, w2])


## Nenhuma suposição sobre a orientação do Magma Dragoon: chefe nativo à direita.
func _new_follow_native_right() -> void:
	var r := _spawn_follow(true, true, {"follow_marker": true, "offset": Vector2(-20, -8),
		"mirror_marker_with_facing": true, "lifetime": 3.0})
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	var w1: float = await _drift(b, inst, Vector2(-20, -8), 3)
	b.facing_right = false
	await _two_frames()
	_expect_pos(_sid + "/after_turn", _disp(inst, b), Vector2(20, -8))
	_expect(_sid + "/following_before_turn", w1 <= POS_EPS, "w1=%.4f" % w1)


## Dono sem get_facing_flip (como o Player): segue sem espelhar.
func _new_follow_player_like() -> void:
	var p := _mk_player(Vector2(100, 100), true)
	var d := _sdef("follow_player", {"follow_marker": true, "offset": Vector2(-20, -8),
		"mirror_marker_with_facing": true, "lifetime": 3.0})
	ParticleFX.spawn_at(d, p.global_position, Vector2.ZERO, p)
	var inst: Node2D = _spawns.back()["node"]
	var w1: float = await _drift(p, inst, Vector2(-20, -8), 3)
	p.facing_right = false
	await _two_frames()
	var w2: float = await _drift(p, inst, Vector2(-20, -8), 3)
	_expect(_sid + "/no_mirror_but_follows", w1 <= POS_EPS and w2 <= POS_EPS, "w1=%.4f w2=%.4f" % [w1, w2])


## Marker "animado": a referência é re-lida todo frame (marker espelhado + offset espelhado).
func _new_follow_marker() -> void:
	var r := _spawn_follow(false, true, {"follow_marker": true, "marker_path": "M", "offset": Vector2(-20, -8),
		"mirror_marker_with_facing": true, "lifetime": 3.0}, {"M": Vector2(10, -5)})
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	_expect_pos(_sid + "/born", inst.global_position, Vector2(110, 87))
	b.global_position = Vector2(160, 100)
	(b.get_node("M") as Node2D).position = Vector2(14, -5)
	await _two_frames()
	_expect_pos(_sid + "/marker_moved", inst.global_position, Vector2(166, 87))
	b.facing_right = false
	await _two_frames()
	_expect_pos(_sid + "/after_turn", inst.global_position, Vector2(154, 87))


## Âncora = nó que já existe na cena (sem criar Marker2D novo).
func _new_follow_sprite_node() -> void:
	var b := _mk_boss(Vector2(100, 100), false, false)
	var sp := Node2D.new()
	sp.name = "Sprite"
	sp.position = Vector2(4, -6)
	b.add_child(sp)
	var d := _sdef("follow_sprite", {"follow_marker": true, "marker_path": "Sprite", "offset": Vector2(0, -10), "lifetime": 3.0})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	var inst: Node2D = _spawns.back()["node"]
	_expect_pos(_sid + "/born", inst.global_position, Vector2(104, 84))
	await _move_and_settle(b, Vector2(150, 120))
	_expect_pos(_sid + "/followed", inst.global_position, Vector2(154, 104))


## A variação aleatória de posição de cada partícula sobrevive ao follow.
func _new_follow_variance() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("follow_variance", {"follow_marker": true, "burst_count": 3, "position_variance": Vector2(10, 5),
		"offset": Vector2(-20, -8), "mirror_marker_with_facing": true, "lifetime": 3.0})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	_expect(_sid + "/three", _spawns.size() == 3, "n=%d" % _spawns.size())
	var before: Array[Vector2] = []
	for sp in _spawns:
		before.append(_disp(sp["node"], b))
	await _move_and_settle(b, Vector2(140, 110))
	var worst := 0.0
	for i in _spawns.size():
		worst = maxf(worst, _disp(_spawns[i]["node"], b).distance_to(before[i]))
	_expect(_sid + "/each_keeps_own_displacement", worst <= POS_EPS, "desvio_max=%.4f" % worst)
	var spread := 0.0
	for i in before.size():
		for j in range(i + 1, before.size()):
			spread = maxf(spread, before[i].distance_to(before[j]))
	_expect(_sid + "/variance_not_flattened", spread > 0.5, "spread=%.3f" % spread)


## Burst com intervalo: cada passo nasce na referência ATUAL do dono (sem voltar ao ponto antigo).
func _new_follow_burst_steps() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("follow_burst", {"follow_marker": true, "burst_count": 3, "spawn_interval": 0.15,
		"offset": Vector2(-20, -8), "mirror_marker_with_facing": true, "lifetime": 3.0})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	await _wait(0.08)
	b.global_position = Vector2(130, 100)
	await _wait(0.15)
	b.global_position = Vector2(170, 100)
	await _wait(0.25)
	_expect(_sid + "/three", _spawns.size() == 3, "n=%d" % _spawns.size())
	for i in _spawns.size():
		var rel: Vector2 = (_spawns[i]["pos"] as Vector2) - (_spawns[i]["opos"] as Vector2)
		_expect_pos("%s/step%d_relative" % [_sid, i], rel, Vector2(20, -8))
	if _spawns.size() == 3:
		_expect(_sid + "/steps_at_different_places", (_spawns[2]["pos"] as Vector2).x > (_spawns[0]["pos"] as Vector2).x + 20.0,
			"x0=%s x2=%s" % [str((_spawns[0]["pos"] as Vector2).x), str((_spawns[2]["pos"] as Vector2).x)])


## spawn_delay + follow: nasce UMA vez, preso ao dono no instante do spawn, e continua seguindo.
func _new_follow_delay() -> void:
	var b := _mk_boss(Vector2(100, 100), false, true)
	var d := _sdef("follow_delay", {"follow_marker": true, "offset": Vector2(-20, -8),
		"mirror_marker_with_facing": true, "spawn_delay": 0.3, "lifetime": 3.0})
	ParticleFX.spawn_at(d, b.global_position, Vector2.ZERO, b)
	await _wait(0.1)
	b.global_position = Vector2(160, 100)
	await _wait(0.4)
	_expect(_sid + "/single_birth", _spawns.size() == 1, "n=%d" % _spawns.size())
	_expect_pos(_sid + "/born_at_fire", _last_pos(), Vector2(180, 92))
	var inst: Node2D = _spawns.back()["node"]
	await _move_and_settle(b, Vector2(220, 100))
	_expect_pos(_sid + "/follows_after_birth", _disp(inst, b), Vector2(20, -8))


## Dono liberado: o FX para de seguir mas termina o fade normalmente (não congela).
func _new_follow_owner_freed() -> void:
	var r := _spawn_follow(false, true, {"follow_marker": true, "marker_path": "M", "fade_out": true,
		"modulate_end": Color(1, 1, 1, 0), "lifetime": 1.0}, {"M": Vector2(10, -5)})
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	await _wait(0.1)
	var pos_before: Vector2 = inst.global_position
	b.free()
	_actors.erase(b)
	await _wait(0.4)
	_expect(_sid + "/still_alive", is_instance_valid(inst), "")
	if is_instance_valid(inst):
		_expect(_sid + "/keeps_fading", inst.modulate.a < 0.9, "alpha=%.3f" % inst.modulate.a)
		_expect_pos(_sid + "/stopped_following", inst.global_position, pos_before)


## Marker removido no meio da vida: para de seguir, sem erro.
func _new_follow_marker_freed() -> void:
	var r := _spawn_follow(false, true, {"follow_marker": true, "marker_path": "M", "lifetime": 3.0}, {"M": Vector2(10, -5)})
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	await _move_and_settle(b, Vector2(120, 100))
	var pos_before: Vector2 = inst.global_position
	(b.get_node("M") as Node2D).free()
	await _two_frames()
	await _move_and_settle(b, Vector2(200, 100))
	_expect(_sid + "/still_alive", is_instance_valid(inst), "")
	if is_instance_valid(inst):
		_expect_pos(_sid + "/stops_following", inst.global_position, pos_before)


## Enquanto segue, o FX não tem movimento próprio (como já era com marker).
func _new_follow_ignores_velocity() -> void:
	var r := _spawn_follow(false, true, {"follow_marker": true, "offset": Vector2(-20, -8),
		"mirror_marker_with_facing": true, "velocity_min": 60.0, "velocity_max": 60.0,
		"base_direction": Vector2.RIGHT, "lifetime": 3.0})
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	var worst: float = await _drift(b, inst, Vector2(20, -8), 5)
	_expect(_sid + "/no_own_motion", worst <= POS_EPS, "desvio_max=%.4f" % worst)


## Contrato inalterado: sem follow, o FX continua se movendo pela própria velocidade.
func _new_follow_false_moves() -> void:
	var d := _sdef("moves", {"velocity_min": 40.0, "velocity_max": 40.0, "base_direction": Vector2.RIGHT, "lifetime": 1.0})
	ParticleFX.spawn_at(d, Vector2(50, 50))
	var inst: Node2D = _spawns.back()["node"]
	await _wait(0.3)
	_expect(_sid + "/moved_right", inst.global_position.x > 55.0, "x=%.2f" % inst.global_position.x)


# ---------------- NEW: rotação espelhada + follow_updates_facing ----------------

func _rot_def(props: Dictionary) -> SpawnedParticleDef:
	var base := {"base_direction": Vector2(0.6, -0.8), "spread_angle": 0.0, "lifetime": 3.0}
	for k in props:
		base[k] = props[k]
	return _sdef("rot", base)


func _spawn_rot(props: Dictionary, facing_right: bool) -> Array:
	var b := _mk_boss(Vector2(100, 100), false, facing_right)
	ParticleFX.spawn_at(_rot_def(props), b.global_position, Vector2.ZERO, b)
	return [b, _spawns.back()["node"]]


func _spr(inst: Node2D) -> AnimatedSprite2D:
	return inst.get("_sprite")


## Rotação do sprite em graus ANTI-HORÁRIOS a partir da arte (como sprite_rotation_degrees os lê).
func _ccw(inst: Node2D) -> float:
	return fposmod(-_spr(inst).rotation_degrees + 180.0, 360.0) - 180.0


func _ang_eq(a: float, b: float) -> bool:
	return absf(fposmod(a - b + 180.0, 360.0) - 180.0) <= 0.01


func _state_is(inst: Node2D, want_flip: bool, want_ccw: float) -> bool:
	return _spr(inst).flip_h == want_flip and _ang_eq(_ccw(inst), want_ccw)


func _state_str(inst: Node2D) -> String:
	return "flip=%s ccw=%.2f" % [str(_spr(inst).flip_h), _ccw(inst)]


## Contrato inalterado: com os flags desligados, a rotação NÃO muda com o lado (só o flip_h).
func _new_rot_flags_off() -> void:
	var props := {"sprite_rotation_degrees": 130.0, "inherit_facing": true}
	var r: Array = _spawn_rot(props, true)
	var l: Array = _spawn_rot(props, false)
	_expect(_sid + "/right", _state_is(r[1], false, 130.0), _state_str(r[1]))
	_expect(_sid + "/left_only_flips_art", _state_is(l[1], true, 130.0), _state_str(l[1]))


func _new_rot_mirror_fixed() -> void:
	var props := {"sprite_rotation_degrees": 130.0, "inherit_facing": true, "mirror_rotation_with_facing": true}
	var r: Array = _spawn_rot(props, true)
	var l: Array = _spawn_rot(props, false)
	_expect(_sid + "/right", _state_is(r[1], false, 130.0), _state_str(r[1]))
	_expect(_sid + "/left_mirrored", _state_is(l[1], true, -130.0), _state_str(l[1]))


func _xf(inst: Node2D, v: Vector2) -> Vector2:
	var s := _spr(inst)
	return Transform2D(s.rotation, Vector2.ZERO) * Vector2(-v.x if s.flip_h else v.x, v.y)


## Prova numérica sobre instâncias reais: o lado esquerdo é a reflexão EXATA do lado direito
## (arte + rotação), para vários ângulos fixos e direções, com e sem rotate_to_direction.
func _new_rot_exact_reflection() -> void:
	var worst := 0.0
	var combos := 0
	for fixed in [0.0, 40.0, 130.0, 230.0]:
		for rtd in [false, true]:
			for dir in [Vector2(0.6, -0.8), Vector2(1, 0), Vector2(0, -1), Vector2(0.9, 0.3)]:
				var props := {"sprite_rotation_degrees": fixed, "rotate_to_direction": rtd, "base_direction": dir,
					"inherit_facing": true, "mirror_rotation_with_facing": true}
				var r: Array = _spawn_rot(props, true)
				var l: Array = _spawn_rot(props, false)
				for v in [Vector2(1, 0), Vector2(0, -1), Vector2(0.6, -0.8), Vector2(-0.3, 0.9)]:
					var pr: Vector2 = _xf(r[1], v)
					var want := Vector2(-pr.x, pr.y)
					worst = maxf(worst, _xf(l[1], v).distance_to(want))
				combos += 1
	_expect(_sid + "/exact_reflection", worst <= 0.0001, "erro_max=%.6f em %d combinações" % [worst, combos])


## O flag só "escuta" o inherit_facing: sem ele, nada espelha.
func _new_rot_needs_inherit() -> void:
	var props := {"sprite_rotation_degrees": 130.0, "inherit_facing": false, "mirror_rotation_with_facing": true}
	var r: Array = _spawn_rot(props, true)
	var l: Array = _spawn_rot(props, false)
	_expect(_sid + "/right", _state_is(r[1], false, 130.0), _state_str(r[1]))
	_expect(_sid + "/left_unchanged", _state_is(l[1], false, 130.0), _state_str(l[1]))


## Dono sem facing_right (nó comum): não espelha e não dá erro.
func _new_rot_owner_without_facing() -> void:
	var o := _mk_plain(Vector2(100, 100))
	var props := {"sprite_rotation_degrees": 130.0, "inherit_facing": true, "mirror_rotation_with_facing": true}
	ParticleFX.spawn_at(_rot_def(props), o.global_position, Vector2.ZERO, o)
	var inst: Node2D = _spawns.back()["node"]
	_expect(_sid + "/no_mirror", _state_is(inst, false, 130.0), _state_str(inst))


func _follow_props(extra: Dictionary) -> Dictionary:
	var p := {"sprite_rotation_degrees": 130.0, "inherit_facing": true, "follow_marker": true}
	for k in extra:
		p[k] = extra[k]
	return p


## Virada do dono com o FX vivo: arte e rotação re-espelhadas no mesmo frame, nos dois sentidos.
func _new_rot_follow_turn() -> void:
	var r: Array = _spawn_rot(_follow_props({"mirror_rotation_with_facing": true, "follow_updates_facing": true}), true)
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	_expect(_sid + "/born_right", _state_is(inst, false, 130.0), _state_str(inst))
	b.facing_right = false
	await _two_frames()
	_expect(_sid + "/turned_left", _state_is(inst, true, -130.0), _state_str(inst))
	b.facing_right = true
	await _two_frames()
	_expect(_sid + "/turned_back", _state_is(inst, false, 130.0), _state_str(inst))


## Sem follow_updates_facing: arte e rotação continuam decididas só no nascimento (como na A1).
func _new_rot_follow_flag_off() -> void:
	var r: Array = _spawn_rot(_follow_props({"mirror_rotation_with_facing": true, "follow_updates_facing": false}), true)
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	b.facing_right = false
	await _two_frames()
	_expect(_sid + "/unchanged_after_turn", _state_is(inst, false, 130.0), _state_str(inst))


## Só a arte re-espelha quando mirror_rotation_with_facing está desligado.
func _new_rot_follow_art_only() -> void:
	var r: Array = _spawn_rot(_follow_props({"mirror_rotation_with_facing": false, "follow_updates_facing": true}), true)
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	b.facing_right = false
	await _two_frames()
	_expect(_sid + "/art_flips_rotation_kept", _state_is(inst, true, 130.0), _state_str(inst))


## O flag só vale enquanto o FX está em follow.
func _new_rot_updates_needs_follow() -> void:
	var r: Array = _spawn_rot(_follow_props({"follow_marker": false, "mirror_rotation_with_facing": true, "follow_updates_facing": true}), true)
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	b.facing_right = false
	await _two_frames()
	_expect(_sid + "/no_effect_without_follow", _state_is(inst, false, 130.0), _state_str(inst))


## E só faz sentido com inherit_facing ligado.
func _new_rot_updates_needs_inherit() -> void:
	var r: Array = _spawn_rot(_follow_props({"inherit_facing": false, "mirror_rotation_with_facing": true, "follow_updates_facing": true}), true)
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	b.facing_right = false
	await _two_frames()
	_expect(_sid + "/no_effect_without_inherit", _state_is(inst, false, 130.0), _state_str(inst))


func _new_rot_follow_owner_freed() -> void:
	var r: Array = _spawn_rot(_follow_props({"mirror_rotation_with_facing": true, "follow_updates_facing": true}), true)
	var b: FakeBoss = r[0]
	var inst: Node2D = r[1]
	await _two_frames()
	b.free()
	_actors.erase(b)
	await _wait(0.2)
	_expect(_sid + "/still_alive", is_instance_valid(inst), "")
	if is_instance_valid(inst):
		_expect(_sid + "/unchanged", _state_is(inst, false, 130.0), _state_str(inst))


## Configuração parecida com a do FireKick: posição na orientação NATIVA do Boss (arte à
## esquerda), arte/rotação na convenção do inherit_facing (autoradas para a DIREITA).
func _new_rot_firekick_like() -> void:
	var props := {"follow_marker": true, "mirror_marker_with_facing": true, "offset": Vector2(-21, 30),
		"sprite_rotation_degrees": 130.0, "rotate_to_direction": false, "inherit_facing": true,
		"mirror_rotation_with_facing": true, "follow_updates_facing": true, "base_direction": Vector2.ZERO}
	var b := _mk_boss(Vector2(100, 100), false, false)   # nativo à esquerda, olhando para a ESQUERDA (nativo)
	ParticleFX.spawn_at(_sdef("firekick_like", props), b.global_position, Vector2.ZERO, b)
	var inst: Node2D = _spawns.back()["node"]
	_expect_pos(_sid + "/pos_native_left", inst.global_position, Vector2(79, 130))
	_expect(_sid + "/art_native_left", _state_is(inst, true, -130.0), _state_str(inst))
	b.facing_right = true
	await _two_frames()
	_expect_pos(_sid + "/pos_after_turn_right", inst.global_position, Vector2(121, 130))
	_expect(_sid + "/art_after_turn_right", _state_is(inst, false, 130.0), _state_str(inst))


# ============================================================
# Saída e comparação com o baseline
# ============================================================

func _finish() -> void:
	var path := "user://a1_%s.txt" % label
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	print("")
	print("A1 harness [%s] — defs reais usadas: %s" % [label, str(_real_used) if not _real_used.is_empty() else "nenhuma (todas sintéticas)"])
	print("A1 harness — log: %s" % ProjectSettings.globalize_path(path))
	print("A1 harness — ASSERT: PASS=%d FAIL=%d" % [_pass, _fail])
	if label != BASELINE_LABEL:
		_compare_with_baseline()


func _compare_with_baseline() -> void:
	var bpath := "user://a1_%s.txt" % BASELINE_LABEL
	if not FileAccess.file_exists(bpath):
		print("A1 harness — sem baseline em %s (rode primeiro com label = baseline)." % ProjectSettings.globalize_path(bpath))
		return
	var base := _parse_groups(FileAccess.get_file_as_string(bpath))
	var diffs := 0
	for sid in _order:
		if String(_groups[sid]["tag"]) != "REG":
			continue
		var cur: PackedStringArray = _groups[sid]["lines"]
		if not base.has(sid):
			print("A1 harness — cenário [REG] novo, sem baseline: %s (ignorado na comparação)" % sid)
			continue
		var ref: PackedStringArray = base.get(sid, PackedStringArray())
		var cur_spawn := _only_spawn(cur)
		var ref_spawn := _only_spawn(ref)
		if cur_spawn != ref_spawn:
			diffs += 1
			print("REGRESSÃO em %s:" % sid)
			print("  baseline: %s" % str(ref_spawn))
			print("  atual   : %s" % str(cur_spawn))
	if diffs == 0:
		print("A1 harness — REGRESSÃO: diff vazio (todos os cenários [REG] idênticos ao baseline).")
	else:
		print("A1 harness — REGRESSÃO: %d cenário(s) divergem do baseline." % diffs)


func _only_spawn(lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for l in lines:
		if l.begins_with("SPAWN|"):
			out.append(l)
	return out


func _parse_groups(text: String) -> Dictionary:
	var res := {}
	var cur := ""
	for l in text.split("\n"):
		if l.begins_with("=== "):
			cur = l.substr(4).split(" [")[0]
			res[cur] = PackedStringArray()
		elif cur != "" and l != "":
			(res[cur] as PackedStringArray).append(l)
	return res
