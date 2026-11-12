extends Node2D
## [A2 · VALIDAÇÃO TEMPORÁRIA — remover na A2.3]
##
## Harness da A2: override de dano do HitComponent (DamageProfile) e leitura do dano efetivo
## pelo HitBus. Mesmo molde do harness da A1.
##
## COMO USAR
##   1. Abra _a2_validation/A2Baseline.tscn e rode a cena (F6).
##   2. O resultado aparece no Output e em user://a2_<label>.txt (o caminho é impresso).
##   3. BASELINE: rode ANTES de aplicar o código da A2 (label = baseline).
##      Depois de cada etapa, mude o label no Inspector (ex.: a2_1) e rode de novo: o harness
##      compara sozinho os cenários [REG] com o baseline e imprime o diff.
##
##   [REG]  regressão: o que o alvo recebe do HitBus precisa ser IDÊNTICO ao baseline.
##   [NEW]  recurso novo, com expectativa calculada aqui dentro (ASSERT PASS/FAIL).
##          No baseline eles falham de propósito (a API ainda não existe).

@export var label: String = "baseline"

const BASELINE_LABEL: String = "baseline"
const PROFILE_PATH: String = "res://systems/damage/DamageProfile.gd"
const API: Array = ["push_override", "pop_override", "clear_overrides", "has_override", "get_damage"]

## Alvo simples: registra o que o HitBus entrega a take_damage().
class FakeTarget extends Node2D:
	var received: Array[Dictionary] = []
	func take_damage(value: float, inflicter: Node) -> void:
		received.append({"value": value, "type": inflicter.get_damage_type_id(), "tag": inflicter.get_damage_tag()})

## Alvo para a física (como o Player: layer 4).
class FakeBody extends CharacterBody2D:
	var received: Array[Dictionary] = []
	func take_damage(value: float, inflicter: Node) -> void:
		received.append({"value": value, "type": inflicter.get_damage_type_id(), "tag": inflicter.get_damage_tag()})

var _nodes: Array[Node] = []
var _sid: String = ""
var _lines: PackedStringArray = []
var _order: Array[String] = []
var _groups: Dictionary = {}
var _pass: int = 0
var _fail: int = 0
var _max_log: int = 12
var _logged: int = 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("label="):
			label = a.substr(6)
	await get_tree().process_frame
	await _run_all()
	_finish()
	get_tree().quit()


# ============================================================
# Infra
# ============================================================

func _mk_hit(damage: float, type_id: StringName, tag: String) -> HitComponent:
	var area := Area2D.new()
	add_child(area)
	_nodes.append(area)
	var hc := HitComponent.new()
	hc.damage = damage
	hc.damage_type_id = type_id
	hc.damage_tag = tag
	area.add_child(hc)
	return hc


func _mk_target() -> FakeTarget:
	var t := FakeTarget.new()
	add_child(t)
	_nodes.append(t)
	return t


func _profile(damage: float, type_id: StringName, tag: String) -> Resource:
	if not ResourceLoader.exists(PROFILE_PATH):
		return null
	var sc: GDScript = load(PROFILE_PATH)
	var p: Resource = sc.new()
	p.set("damage", damage)
	p.set("damage_type_id", type_id)
	p.set("damage_tag", tag)
	return p


func _api_ready(hc: HitComponent) -> bool:
	for m in API:
		if not hc.has_method(m):
			return false
	return _profile(1.0, &"contact", "") != null


func _push(hc: HitComponent, token: Object, p: Resource) -> void:
	hc.call("push_override", token, p)


func _pop(hc: HitComponent, token: Object) -> void:
	hc.call("pop_override", token)


func _eff(hc: HitComponent) -> Dictionary:
	return {"damage": hc.call("get_damage"), "type": hc.get_damage_type_id(), "tag": hc.get_damage_tag()}


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _clean() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()


func _emit(line: String) -> void:
	_lines.append(line)
	if _groups.has(_sid):
		(_groups[_sid]["lines"] as PackedStringArray).append(line)


func _evt(entries: Array) -> void:
	for e in entries:
		_logged += 1
		if _logged <= _max_log:
			_emit("EVT|value=%.3f|type=%s|tag=%s" % [float(e["value"]), str(e["type"]), str(e["tag"])])


func _scenario(sid: String, tag: String, body: Callable, tail_s: float = 0.05, max_log: int = 12) -> void:
	_sid = sid
	_max_log = max_log
	_logged = 0
	_order.append(sid)
	_groups[sid] = {"tag": tag, "lines": PackedStringArray()}
	_lines.append("=== %s [%s] ===" % [sid, tag])
	await body.call()
	await _wait(tail_s)
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


func _near(a: float, b: float) -> bool:
	return absf(a - b) <= 0.0001


func _is_eff(hc: HitComponent, damage: float, type_id: StringName, tag: String) -> bool:
	var e := _eff(hc)
	return _near(float(e["damage"]), damage) and e["type"] == type_id and e["tag"] == tag


func _fmt(hc: HitComponent) -> String:
	var e := _eff(hc)
	return "dano=%s tipo=%s tag='%s'" % [str(e["damage"]), str(e["type"]), str(e["tag"])]


# ============================================================
# Cenários
# ============================================================

func _run_all() -> void:
	# ---------------- REGRESSÃO (idêntico ao baseline) ----------------
	await _scenario("REG_dispatch_base_values", "REG", _reg_base_values)
	await _scenario("REG_dispatch_repeat", "REG", _reg_repeat)
	await _scenario("REG_dispatch_ignored_targets", "REG", _reg_ignored)
	await _scenario("REG_dispatch_base_changed_at_runtime", "REG", _reg_base_changed)
	await _scenario("REG_contact_continuous_physics", "REG", _reg_continuous, 0.05, 3)
	await _scenario("REG_on_enter_physics", "REG", _reg_on_enter, 0.05, 3)

	# ---------------- RECURSO NOVO: override com token ----------------
	await _scenario("NEW_api_present", "NEW", _new_api_present)
	await _scenario("NEW_override_base_never_changes", "NEW", _new_base_never_changes)
	await _scenario("NEW_override_dispatch_uses_effective", "NEW", _new_dispatch_effective)
	await _scenario("NEW_override_same_token_replaces", "NEW", _new_same_token)
	await _scenario("NEW_override_stack_two_tokens", "NEW", _new_stack)
	await _scenario("NEW_override_pop_idempotent", "NEW", _new_pop_idempotent)
	await _scenario("NEW_override_clear", "NEW", _new_clear)
	await _scenario("NEW_override_freed_token_dropped", "NEW", _new_freed_token)
	await _scenario("NEW_override_null_ignored", "NEW", _new_null_ignored)
	await _scenario("NEW_override_replaces_whole_trio", "NEW", _new_whole_trio)
	await _scenario("NEW_override_independent_components", "NEW", _new_independent)
	await _scenario("NEW_override_base_writes_survive", "NEW", _new_base_writes_survive)
	await _scenario("NEW_override_continuous_physics", "NEW", _new_continuous_physics, 0.05)


# ---------------- REG ----------------

func _reg_base_values() -> void:
	for c in [[3.0, &"contact", "contact"], [4.0, &"fire", "fire"], [0.0, &"contact", ""], [7.5, &"buster", "buster"], [1.0, &"ice", ""]]:
		var hc := _mk_hit(c[0], c[1], c[2])
		var t := _mk_target()
		hc.report(t)
		_evt(t.received)


func _reg_repeat() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	var t := _mk_target()
	for i in 3:
		hc.report(t)
	_evt(t.received)


func _reg_ignored() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	var t := _mk_target()
	hc.attacker = t
	hc.report(t)                      # o próprio atacante: ignorado
	var plain := Node2D.new()
	add_child(plain)
	_nodes.append(plain)
	hc.report(plain)                  # sem take_damage: ignorado
	_emit("COUNT|received=%d" % t.received.size())


## Quem spawna o objeto (PillarHazard, Boss.bind_spawned_object...) escreve na base depois do _ready.
func _reg_base_changed() -> void:
	var hc := _mk_hit(1.0, &"contact", "")
	var t := _mk_target()
	hc.damage = 4.0
	hc.damage_type_id = &"fire"
	hc.damage_tag = "fire"
	hc.report(t)
	_evt(t.received)


func _mk_physics(mode: HitComponent.ReportMode, damage: float, type_id: StringName, tag: String) -> Array:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	area.add_child(shape)
	var hc := HitComponent.new()
	hc.damage = damage
	hc.damage_type_id = type_id
	hc.damage_tag = tag
	hc.auto_report = true
	hc.report_mode = mode
	hc.recheck_interval = 0.02
	area.add_child(hc)
	add_child(area)
	_nodes.append(area)
	var body := FakeBody.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var bshape := CollisionShape2D.new()
	var bcircle := CircleShape2D.new()
	bcircle.radius = 6.0
	bshape.shape = bcircle
	body.add_child(bshape)
	add_child(body)
	_nodes.append(body)
	return [hc, body]


func _reg_continuous() -> void:
	var r := _mk_physics(HitComponent.ReportMode.CONTINUOUS, 3.0, &"contact", "contact")
	await _wait(0.3)
	_evt((r[1] as FakeBody).received)


func _reg_on_enter() -> void:
	var r := _mk_physics(HitComponent.ReportMode.ON_ENTER, 4.0, &"fire", "fire")
	await _wait(0.3)
	_evt((r[1] as FakeBody).received)


# ---------------- NEW ----------------

func _new_api_present() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	for m in API:
		_expect("%s/%s" % [_sid, m], hc.has_method(m), "")
	_expect(_sid + "/DamageProfile", ResourceLoader.exists(PROFILE_PATH), PROFILE_PATH)


func _need_api(hc: HitComponent) -> bool:
	if _api_ready(hc):
		return true
	_expect(_sid + "/api", false, "API ausente (esperado antes da A2.1)")
	return false


## A base (damage, damage_type_id, damage_tag) nunca é alterada pelo override.
func _new_base_never_changes() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	if not _need_api(hc):
		return
	var a := RefCounted.new()
	_push(hc, a, _profile(8.0, &"fire", "fire"))
	_expect(_sid + "/effective_during", _is_eff(hc, 8.0, &"fire", "fire"), _fmt(hc))
	_expect(_sid + "/base_untouched_during", _near(hc.damage, 3.0) and hc.damage_type_id == &"contact" and hc.damage_tag == "contact",
		"base: %s %s '%s'" % [str(hc.damage), str(hc.damage_type_id), hc.damage_tag])
	_expect(_sid + "/has_override", bool(hc.call("has_override")), "")
	_pop(hc, a)
	_expect(_sid + "/restored", _is_eff(hc, 3.0, &"contact", "contact"), _fmt(hc))
	_expect(_sid + "/no_override_after", not bool(hc.call("has_override")), "")


## O HitBus entrega ao alvo o valor EFETIVO (dano, tipo e tag).
func _new_dispatch_effective() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	if not _need_api(hc):
		return
	var t := _mk_target()
	var a := RefCounted.new()
	hc.report(t)
	_push(hc, a, _profile(8.0, &"fire", "fire"))
	hc.report(t)
	_pop(hc, a)
	hc.report(t)
	var r: Array[Dictionary] = t.received
	_expect(_sid + "/three_reports", r.size() == 3, "n=%d" % r.size())
	if r.size() == 3:
		_expect(_sid + "/before", _near(r[0]["value"], 3.0) and r[0]["type"] == &"contact" and r[0]["tag"] == "contact", str(r[0]))
		_expect(_sid + "/during", _near(r[1]["value"], 8.0) and r[1]["type"] == &"fire" and r[1]["tag"] == "fire", str(r[1]))
		_expect(_sid + "/after", _near(r[2]["value"], 3.0) and r[2]["type"] == &"contact" and r[2]["tag"] == "contact", str(r[2]))


## Mesmo token de novo substitui a entrada (não empilha): um único pop devolve a base.
func _new_same_token() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	if not _need_api(hc):
		return
	var a := RefCounted.new()
	_push(hc, a, _profile(8.0, &"fire", "fire"))
	_push(hc, a, _profile(5.0, &"ice", "ice"))
	_expect(_sid + "/replaced", _is_eff(hc, 5.0, &"ice", "ice"), _fmt(hc))
	var pile: Array = hc.get("_overrides")
	_expect(_sid + "/no_growth_same_token", pile.size() == 1, "tamanho da pilha=%d" % pile.size())
	_pop(hc, a)
	_expect(_sid + "/single_pop_restores_base", _is_eff(hc, 3.0, &"contact", "contact"), _fmt(hc))


## Dois tokens: o último vale; a ordem dos pops não importa.
func _new_stack() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	if not _need_api(hc):
		return
	var a := RefCounted.new()
	var b := RefCounted.new()
	_push(hc, a, _profile(8.0, &"fire", "fire"))
	_push(hc, b, _profile(5.0, &"ice", "ice"))
	_expect(_sid + "/top_is_b", _is_eff(hc, 5.0, &"ice", "ice"), _fmt(hc))
	_pop(hc, b)
	_expect(_sid + "/pop_top_reveals_a", _is_eff(hc, 8.0, &"fire", "fire"), _fmt(hc))
	_pop(hc, a)
	_expect(_sid + "/pop_a_restores_base", _is_eff(hc, 3.0, &"contact", "contact"), _fmt(hc))
	# ordem inversa: remove o de baixo primeiro; o de cima continua valendo
	_push(hc, a, _profile(8.0, &"fire", "fire"))
	_push(hc, b, _profile(5.0, &"ice", "ice"))
	_pop(hc, a)
	_expect(_sid + "/pop_lower_keeps_top", _is_eff(hc, 5.0, &"ice", "ice"), _fmt(hc))
	_pop(hc, b)
	_expect(_sid + "/then_base", _is_eff(hc, 3.0, &"contact", "contact"), _fmt(hc))


func _new_pop_idempotent() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	if not _need_api(hc):
		return
	var a := RefCounted.new()
	var stranger := RefCounted.new()
	_pop(hc, stranger)                                   # pilha vazia
	_expect(_sid + "/pop_on_empty", _is_eff(hc, 3.0, &"contact", "contact"), _fmt(hc))
	_push(hc, a, _profile(8.0, &"fire", "fire"))
	_pop(hc, stranger)                                   # token que nunca entrou
	_expect(_sid + "/pop_stranger_keeps_override", _is_eff(hc, 8.0, &"fire", "fire"), _fmt(hc))
	_pop(hc, a)
	_pop(hc, a)                                          # de novo
	_expect(_sid + "/double_pop", _is_eff(hc, 3.0, &"contact", "contact"), _fmt(hc))


func _new_clear() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	if not _need_api(hc):
		return
	_push(hc, RefCounted.new(), _profile(8.0, &"fire", "fire"))
	var keep := RefCounted.new()
	_push(hc, keep, _profile(5.0, &"ice", "ice"))
	hc.call("clear_overrides")
	_expect(_sid + "/base_after_clear", _is_eff(hc, 3.0, &"contact", "contact"), _fmt(hc))
	_expect(_sid + "/no_override", not bool(hc.call("has_override")), "")


## Token liberado da memória não deixa o override preso.
func _new_freed_token() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	if not _need_api(hc):
		return
	var a := RefCounted.new()
	var tmp := Node.new()
	_push(hc, a, _profile(8.0, &"fire", "fire"))
	_push(hc, tmp, _profile(5.0, &"ice", "ice"))
	tmp.free()
	_expect(_sid + "/freed_top_dropped", _is_eff(hc, 8.0, &"fire", "fire"), _fmt(hc))
	_pop(hc, a)
	_expect(_sid + "/then_base", _is_eff(hc, 3.0, &"contact", "contact"), _fmt(hc))


func _new_null_ignored() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	if not _need_api(hc):
		return
	_push(hc, RefCounted.new(), null)
	_expect(_sid + "/null_profile", _is_eff(hc, 3.0, &"contact", "contact") and not bool(hc.call("has_override")), _fmt(hc))


## O override substitui o trio inteiro: campos que o perfil deixa no padrão valem como padrão.
func _new_whole_trio() -> void:
	var hc := _mk_hit(3.0, &"fire", "fire")
	if not _need_api(hc):
		return
	var a := RefCounted.new()
	_push(hc, a, _profile(8.0, DamageType.CONTACT, ""))
	_expect(_sid + "/all_three_replaced", _is_eff(hc, 8.0, &"contact", ""), _fmt(hc))
	_pop(hc, a)
	_expect(_sid + "/base_back", _is_eff(hc, 3.0, &"fire", "fire"), _fmt(hc))


func _new_independent() -> void:
	var h1 := _mk_hit(3.0, &"contact", "contact")
	var h2 := _mk_hit(4.0, &"ice", "ice")
	if not _need_api(h1):
		return
	var a := RefCounted.new()
	_push(h1, a, _profile(8.0, &"fire", "fire"))
	_expect(_sid + "/other_untouched", _is_eff(h2, 4.0, &"ice", "ice") and not bool(h2.call("has_override")), _fmt(h2))
	_expect(_sid + "/this_overridden", _is_eff(h1, 8.0, &"fire", "fire"), _fmt(h1))


## Quem spawna (PillarHazard, bind_spawned_object) escreve na base: isso não se perde nem fura o override.
func _new_base_writes_survive() -> void:
	var hc := _mk_hit(3.0, &"contact", "contact")
	if not _need_api(hc):
		return
	var a := RefCounted.new()
	_push(hc, a, _profile(8.0, &"fire", "fire"))
	hc.damage = 5.0
	hc.damage_tag = "ice"
	_expect(_sid + "/override_still_wins", _is_eff(hc, 8.0, &"fire", "fire"), _fmt(hc))
	_pop(hc, a)
	_expect(_sid + "/new_base_visible_after_pop", _is_eff(hc, 5.0, &"contact", "ice"), _fmt(hc))


## Física real: contato CONTINUOUS tocando um alvo. O dano recebido segue o override e volta à base.
func _new_continuous_physics() -> void:
	var r := _mk_physics(HitComponent.ReportMode.CONTINUOUS, 3.0, &"contact", "contact")
	var hc: HitComponent = r[0]
	var body: FakeBody = r[1]
	if not _need_api(hc):
		return
	await _wait(0.25)
	var b0: Array[Dictionary] = body.received
	_expect(_sid + "/receives_base", not b0.is_empty() and _near(b0.back()["value"], 3.0) and b0.back()["tag"] == "contact", "n=%d" % b0.size())
	var a := RefCounted.new()
	_push(hc, a, _profile(8.0, &"fire", "fire"))
	await _wait(0.25)
	var b1: Array[Dictionary] = body.received
	_expect(_sid + "/receives_override", _near(b1.back()["value"], 8.0) and b1.back()["type"] == &"fire", str(b1.back()))
	_pop(hc, a)
	await _wait(0.25)
	var b2: Array[Dictionary] = body.received
	_expect(_sid + "/receives_base_again", _near(b2.back()["value"], 3.0) and b2.back()["type"] == &"contact", str(b2.back()))


# ============================================================
# Saída e comparação com o baseline
# ============================================================

func _finish() -> void:
	var path := "user://a2_%s.txt" % label
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	print("")
	print("A2 harness [%s]" % label)
	print("A2 harness — log: %s" % ProjectSettings.globalize_path(path))
	print("A2 harness — ASSERT: PASS=%d FAIL=%d" % [_pass, _fail])
	if label != BASELINE_LABEL:
		_compare_with_baseline()


func _compare_with_baseline() -> void:
	var bpath := "user://a2_%s.txt" % BASELINE_LABEL
	if not FileAccess.file_exists(bpath):
		print("A2 harness — sem baseline em %s (rode primeiro com label = baseline)." % ProjectSettings.globalize_path(bpath))
		return
	var base := _parse_groups(FileAccess.get_file_as_string(bpath))
	var diffs := 0
	for sid in _order:
		if String(_groups[sid]["tag"]) != "REG":
			continue
		if not base.has(sid):
			print("A2 harness — cenário [REG] novo, sem baseline: %s (ignorado)" % sid)
			continue
		var cur := _only_evt(_groups[sid]["lines"])
		var ref := _only_evt(base[sid])
		if cur != ref:
			diffs += 1
			print("REGRESSÃO em %s:" % sid)
			print("  baseline: %s" % str(ref))
			print("  atual   : %s" % str(cur))
	if diffs == 0:
		print("A2 harness — REGRESSÃO: diff vazio (todos os cenários [REG] idênticos ao baseline).")
	else:
		print("A2 harness — REGRESSÃO: %d cenário(s) divergem do baseline." % diffs)


func _only_evt(lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for l in lines:
		if l.begins_with("EVT|") or l.begins_with("COUNT|"):
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
