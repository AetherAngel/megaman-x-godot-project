extends Node2D
## [HITBOX · BATCH 0 — VALIDAÇÃO TEMPORÁRIA — remover ao fim da tarefa de hitbox]
##
## Baseline de comportamento das BossActions e dos FrameEvents do Boss. NÃO testa nada novo:
## congela o que já funciona para que os próximos batches (HitboxDef/HitboxArea, gancho no
## BossAction, prioridade) possam provar que não quebraram nenhum ataque.
## Mesmo molde do harness da A2.
##
## COMO USAR
##   1. Copie esta pasta para res://_hitbox_validation/ e rode HitboxBaseline.tscn (F6).
##      Também roda por linha de comando:  godot --path . res://_hitbox_validation/HitboxBaseline.tscn -- label=baseline
##   2. O resultado aparece no Output e em user://hitbox_<label>.txt (o caminho é impresso).
##   3. BASELINE: rode ANTES de qualquer mudança de código (label = baseline).
##      Depois de cada batch, mude o label no Inspector (ex.: b2) e rode de novo: o harness
##      compara sozinho os cenários [REG] com o baseline e imprime o diff.
##      NUNCA regenere o baseline depois de mudar código: isso esconderia a regressão.
##
##   [REG]  regressão: o transcript tem que ser IDÊNTICO ao baseline.
##   [CHK]  auto-verificação do próprio harness: deve dar PASS já no baseline.
##
## O QUE É OBSERVADO (o contrato que os batches não podem alterar)
##   EVT  cada FrameEvent despachado: fase, frame, tipo, valor e referências.
##   ACT  cada chamada que a ação faz no ator (set_visual_state, spawn_object, física, contato...).
##   END  como a ação terminou e o estado do ator depois (acting, invulnerabilidade, contato).
##   DAT  os dados carregados dos .tres (pega reordenar o enum FrameEvent.Type ou renomear campo).
##
## COMO É DETERMINÍSTICO
##   Cada ação roda isolada num ator falso, com delta fixo (1/60) e frames de animação
##   avançados à mão (1 frame a cada FRAME_TICKS ticks). Sem luta, sem sorteio, sem relógio.
##   O BarrageController (único com _process próprio) é avançado à mão com o mesmo delta,
##   com semente fixa (HARNESS_SEED) e dentro de um SubViewport de tamanho fixo (VIEW_SIZE).
##   Cada ação roda em até 3 cenários: normal, interrupt (finish() no meio) e recovery
##   (pouso inseguro na 1ª checagem, só para ações com recovery_phases).
##
## PONTO DE OBSERVAÇÃO
##   O TracedAction sobrescreve BossAction._dispatch_event só para registrar e chama o original
##   (super). Se um batch futuro mover esse despacho de lugar, este é o único ponto a adaptar.

@export var label: String = "baseline"

const BASELINE_LABEL: String = "baseline"
const SCAN_ROOT: String = "res://enemies"
const DT: float = 1.0 / 60.0
const FRAME_TICKS: int = 5          # 12 fps de animação a 60 ticks/s
const MIN_FRAMES: int = 12          # mínimo de frames por animação falsa
const MOVE_TICKS: int = 20          # duração do physical_move falso
const MAX_TICKS: int = 1800         # 30 s: trava contra ação que nunca termina
const INTERRUPT_AT: int = 20        # tick em que o cenário "interrupt" chama finish()
const HARNESS_SEED: int = 20260101  # sorteio das lanes do Barrage (seed_value = 0 no .tres)
const VIEW_SIZE: Vector2i = Vector2i(1152, 648)   # viewport fixo p/ o Barrage (independe da janela)
const TRACE_PREFIXES: Array[String] = ["EVT|", "ACT|", "END|", "DAT|"]


# ============================================================
# Utilitários e atores falsos
# ============================================================

class U:
	## Identifica um Resource de forma estável: classe do script + caminho (com ::id se embutido).
	static func rid(r: Resource) -> String:
		if r == null:
			return "null"
		var cls: String = ""
		var sc: Variant = r.get_script()
		if sc is Script:
			cls = (sc as Script).get_global_name()
		if cls == "":
			cls = r.get_class()
		var p: String = r.resource_path
		return "%s@%s" % [cls, p if p != "" else "<local>"]

	static func count_nodes(n: Node) -> int:
		var c: int = 1
		for ch in n.get_children():
			c += count_nodes(ch)
		return c

	static func type_name(t: int) -> String:
		for k in FrameEvent.Type:
			if FrameEvent.Type[k] == t:
				return String(k)
		return "?%d" % t


## BossAction que registra cada FrameEvent despachado e depois executa o despacho ORIGINAL.
class TracedAction extends BossAction:
	var sink: Callable = Callable()
	var fired: Dictionary = {}

	func _dispatch_event(actor: Node, event: FrameEvent) -> void:
		fired[event.get_instance_id()] = true
		var scene: Node = actor.get_tree().current_scene
		var before: int = U.count_nodes(scene)
		super._dispatch_event(actor, event)
		if sink.is_valid():
			var ph: String = ("R%d" % _recovery_index) if _in_recovery else str(_phase_index)
			# new_nodes = nós criados na cena pelo despacho (FX/objetos reais): enxerga o efeito.
			sink.call("EVT", "ph=%s|fr=%d|type=%s|val=%s|part=%s|fx=%s|obj=%s|new_nodes=%d" % [
				ph, event.frame, U.type_name(event.type), event.value,
				U.rid(event.particle_def), U.rid(event.fx_resource), U.rid(event.spawn_object),
				U.count_nodes(scene) - before])


## Objeto "spawnado" falso: só registra release().
class FakeSpawned extends Node2D:
	var sink: Callable = Callable()

	func release() -> void:
		if sink.is_valid():
			sink.call("ACT", "spawned.release")


## Ator falso com a API que o BossAction usa (mesmas assinaturas do Boss/Actor).
class FakeBoss extends Node2D:
	var sink: Callable = Callable()
	var tracked: Object = null            # a ação em teste (token do contato)
	var is_acting: bool = false
	var toggleable_invulnerabilities: Array = []
	var facing_right: bool = true
	var contact_stack: Array = []
	var frames_for: Dictionary = {}       # String(anim) -> nº de frames
	var landing_unsafe_left: int = 0
	var move_left: int = 0
	var anim_ticks: int = 0
	var sprite: AnimatedSprite2D = null
	var frames: SpriteFrames = null

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_DISABLED
		sprite = AnimatedSprite2D.new()
		sprite.name = "Sprite"
		frames = SpriteFrames.new()
		sprite.sprite_frames = frames
		add_child(sprite)

	func _log(body: String) -> void:
		if sink.is_valid():
			sink.call("ACT", body)

	func _tok(token: Object) -> String:
		return "action" if token == tracked else "other"

	# -- visual -------------------------------------------------
	func set_visual_state(anim_name: StringName) -> void:
		_log("set_visual_state|anim=%s" % anim_name)
		var key: String = String(anim_name)
		if not frames.has_animation(anim_name):
			frames.add_animation(anim_name)
			frames.set_animation_loop(anim_name, false)
			frames.set_animation_speed(anim_name, 12.0)
			var tex := PlaceholderTexture2D.new()
			for i in int(frames_for.get(key, MIN_FRAMES)):
				frames.add_frame(anim_name, tex)
		sprite.animation = anim_name
		sprite.frame = 0
		anim_ticks = 0
		sprite.play(anim_name)

	## Fim de cada tick: avança 1 frame de animação a cada FRAME_TICKS ticks e para no último.
	func step() -> void:
		if move_left > 0:
			move_left -= 1
		anim_ticks += 1
		var n: int = frames.get_frame_count(sprite.animation)
		if n <= 0:
			return
		var f: int = floori(float(anim_ticks) / float(FRAME_TICKS))
		if f >= n:
			sprite.frame = n - 1
			if sprite.is_playing():
				sprite.pause()
		else:
			sprite.frame = f

	# -- movimento físico --------------------------------------
	func start_physical_move(move_def: PhysicalMoveDef) -> void:
		move_left = MOVE_TICKS
		_log("start_physical_move|def=%s" % U.rid(move_def))

	func stop_physical_move() -> void:
		move_left = 0
		_log("stop_physical_move")

	func is_doing_physical_move() -> bool:
		return move_left > 0

	# -- recuperação / pouso -----------------------------------
	func mark_recovery_anchor() -> void:
		_log("mark_recovery_anchor")

	func is_landing_safe() -> bool:
		return landing_unsafe_left <= 0

	func prepare_recovery(move_def: PhysicalMoveDef) -> bool:
		landing_unsafe_left -= 1
		_log("prepare_recovery|def=%s" % U.rid(move_def))
		return true

	func recovery_failsafe() -> void:
		_log("recovery_failsafe")

	# -- objetos ------------------------------------------------
	func spawn_object(obj: SpawnableObject) -> Node2D:
		_log("spawn_object|def=%s|scene=%s" % [U.rid(obj), str(obj.get("scene_path"))])
		var n := FakeSpawned.new()
		n.sink = sink
		add_child(n)
		return n

	func bind_spawned_object(instance: Node2D, obj: SpawnableObject = null) -> void:
		_log("bind_spawned_object|cls=%s|obj=%s" % [instance.get_class(), U.rid(obj)])

	# -- contato / facing --------------------------------------
	func push_contact_override(token: Object, profile: DamageProfile) -> void:
		contact_stack.append(token)
		_log("contact_push|token=%s|dmg=%s|type=%s|tag=%s" % [
			_tok(token), str(profile.damage), str(profile.damage_type_id), profile.damage_tag])

	func pop_contact_override(token: Object) -> void:
		var had: bool = contact_stack.has(token)
		contact_stack.erase(token)
		_log("contact_pop|token=%s|had=%s" % [_tok(token), str(had)])

	func get_facing_flip() -> int:
		return 1


# ============================================================
# Estado do harness
# ============================================================

var _nodes: Array[Node] = []
var _lines: PackedStringArray = []
var _order: Array[String] = []
var _groups: Dictionary = {}
var _sid: String = ""
var _tick: int = 0
var _pass: int = 0
var _fail: int = 0
var _driven: Array[BarrageController] = []
var _all_events: Dictionary = {}   # instance_id -> descrição
var _fired: Dictionary = {}        # instance_id -> true
var _was_muted: bool = false
var _base_children: Array[Node] = []   # filhos do harness que NÃO são lixo de cenário
var _vp: SubViewport = null            # viewport de tamanho fixo onde o Barrage roda
var _actions: Array = []           # [{name, res}] ordenado


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("label="):
			label = a.substr(6)
	var bus: int = AudioServer.get_bus_index("Master")
	_was_muted = AudioServer.is_bus_mute(bus)
	AudioServer.set_bus_mute(bus, true)   # os SFX dos eventos rodam de verdade: silencia
	_vp = SubViewport.new()
	_vp.size = VIEW_SIZE
	add_child(_vp)
	await get_tree().process_frame
	_base_children = get_children()
	await _run_all()
	_finish()
	AudioServer.set_bus_mute(bus, _was_muted)
	get_tree().quit()


# ============================================================
# Infra (mesmo molde da A2)
# ============================================================

## ATENÇÃO: os grupos usam Array (por referência). (dict[...] as PackedStringArray).append()
## acrescenta numa CÓPIA no Godot 4.6 e deixaria o grupo vazio: a comparação ficaria cega.
func _emit(line: String) -> void:
	_lines.append(line)
	if _groups.has(_sid):
		var arr: Array = _groups[_sid]["lines"]
		arr.append(line)


func _sink(kind: String, body: String) -> void:
	_emit("%s|t=%d|%s" % [kind, _tick, body])


func _scenario(sid: String, tag: String, body: Callable) -> void:
	_sid = sid
	_order.append(sid)
	_groups[sid] = {"tag": tag, "lines": []}
	_lines.append("=== %s [%s] ===" % [sid, tag])
	await body.call()
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


func _clean() -> void:
	for c in _driven:
		if is_instance_valid(c):
			c.queue_free()
	_driven.clear()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	# Tudo que os efeitos reais criaram no cenário atual (FXContainer, controllers, projéteis).
	for c in get_children():
		if not _base_children.has(c):
			c.queue_free()


func _safe_name(path: String) -> String:
	var s: String = path.replace("res://enemies/boss/characters/", "")
	var out: String = ""
	for ch in s:
		out += ch if (ch.unicode_at(0) < 128 and (ch.to_lower() != ch.to_upper() or ch.is_valid_int())) else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_")


# ============================================================
# Varredura: acha TODA BossAction alcançável (sem lista fixa)
# ============================================================

func _scan_tres(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full: String = dir_path.path_join(entry)
			if d.current_is_dir():
				_scan_tres(full, out)
			elif entry.ends_with(".tres"):
				out.append(full)
		entry = d.get_next()
	d.list_dir_end()


func _gather(res: Variant, found: Dictionary) -> void:
	if res == null:
		return
	if res is BossAction:
		var p: String = (res as BossAction).resource_path
		if p != "":
			found[p] = res
	elif res is AttackPattern:
		for a in (res as AttackPattern).attacks:
			_gather(a, found)
	elif res is BossPhaseData:
		for p in (res as BossPhaseData).patterns:
			_gather(p, found)
		_gather((res as BossPhaseData).entry_pattern, found)
	elif res is BossData:
		for ph in (res as BossData).phases:
			_gather(ph, found)


func _collect_actions() -> void:
	var paths: Array[String] = []
	_scan_tres(SCAN_ROOT, paths)
	paths.sort()
	var found: Dictionary = {}
	for p in paths:
		_gather(load(p), found)
	var keys: Array = found.keys()
	keys.sort()
	_actions.clear()
	for k in keys:
		_actions.append({"name": _safe_name(String(k)), "res": found[k], "path": String(k)})
		var act: BossAction = found[k]
		for ph in act.phases + act.recovery_phases:
			for e in ph.frame_events:
				_all_events[e.get_instance_id()] = "%s|fr=%d|type=%s" % [_safe_name(String(k)), e.frame, U.type_name(e.type)]


# ============================================================
# Execução de uma ação isolada
# ============================================================

func _frames_needed(src: BossAction) -> Dictionary:
	var need: Dictionary = {}
	for ph in src.phases + src.recovery_phases:
		var mx: int = MIN_FRAMES
		for e in ph.frame_events:
			mx = maxi(mx, e.frame + 3)
		var key: String = String(ph.anim_name)
		need[key] = maxi(int(need.get(key, 0)), mx)
	return need


func _drive_barrages() -> void:
	for c in get_children():
		if c is BarrageController and not _driven.has(c):
			c.process_mode = Node.PROCESS_MODE_DISABLED   # avançado à mão, com delta fixo
			c._rng.seed = HARNESS_SEED                    # lanes determinísticas
			c.reparent(_vp)                               # _view_rect() não depende da janela
			_driven.append(c)
	for c in _driven:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			c._process(DT)


func _snapshot(boss: FakeBoss) -> String:
	return "acting=%s|invuln_tokens=%d|contact_tokens=%d|moving=%s" % [
		str(boss.is_acting), boss.toggleable_invulnerabilities.size(),
		boss.contact_stack.size(), str(boss.is_doing_physical_move())]


func _run_action(src: BossAction, mode: String) -> void:
	var act := TracedAction.new()
	act.phases = src.phases
	act.contact_override = src.contact_override
	act.recovery_phases = src.recovery_phases
	act.max_recovery_attempts = src.max_recovery_attempts
	act.sink = _sink

	var boss := FakeBoss.new()
	boss.sink = _sink
	boss.tracked = act
	boss.frames_for = _frames_needed(src)
	boss.landing_unsafe_left = 1 if mode == "recovery" else 0
	add_child(boss)
	_nodes.append(boss)

	var script_path: String = ""
	var sc: Variant = src.get_script()
	if sc is Script:
		script_path = (sc as Script).resource_path
	_tick = 0
	_emit("DAT|mode=%s|script=%s|phases=%d|recovery_phases=%d|max_recovery=%d|contact=%s" % [
		mode, script_path, src.phases.size(), src.recovery_phases.size(),
		src.max_recovery_attempts, U.rid(src.contact_override)])

	var limit: int = INTERRUPT_AT if mode == "interrupt" else MAX_TICKS
	var done: bool = false
	for i in limit:
		_tick = i + 1
		if i == 0:
			act.start(boss)
		_drive_barrages()
		done = act.update(boss, DT)
		if done:
			break
		boss.step()
	var result: String = "done" if done else ("interrupted" if mode == "interrupt" else "TIMEOUT")
	_emit("END|result=%s|ticks=%d|before_finish:%s" % [result, _tick, _snapshot(boss)])
	act.finish(boss)   # BTAction chama finish() no fim normal e na interrupção
	_emit("END|after_finish:%s" % _snapshot(boss))
	for id in act.fired:
		_fired[id] = true


# ============================================================
# Cenários
# ============================================================

func _run_all() -> void:
	_collect_actions()

	await _scenario("REG_data_enum", "REG", _reg_data_enum)
	await _scenario("REG_data_actions", "REG", _reg_data_actions)

	for item in _actions:
		var src: BossAction = item["res"]
		var base: String = "REG_act_%s" % item["name"]
		await _scenario(base + "__normal", "REG", func() -> void: _run_action(src, "normal"))
		await _scenario(base + "__interrupt", "REG", func() -> void: _run_action(src, "interrupt"))
		if not src.recovery_phases.is_empty():
			await _scenario(base + "__recovery", "REG", func() -> void: _run_action(src, "recovery"))

	await _scenario("CHK_harness", "CHK", _chk_harness)


## Congela os valores do enum: reordenar FrameEvent.Type quebra os .tres em silêncio.
func _reg_data_enum() -> void:
	for k in FrameEvent.Type:
		_emit("DAT|FrameEvent.Type|%s=%d" % [k, FrameEvent.Type[k]])


## Congela os dados carregados de cada ação: fases e eventos, como o jogo os enxerga.
func _reg_data_actions() -> void:
	for item in _actions:
		var act: BossAction = item["res"]
		var all_phases: Array = []
		for i in act.phases.size():
			all_phases.append(["P%d" % i, act.phases[i]])
		for i in act.recovery_phases.size():
			all_phases.append(["R%d" % i, act.recovery_phases[i]])
		for pair in all_phases:
			var ph: AnimPhase = pair[1]
			_emit("DAT|act=%s|ph=%s|anim=%s|exit=%d|timer=%s|timeout=%s|move=%s|landing=%s|invuln=%s|events=%d" % [
				item["name"], pair[0], ph.anim_name, ph.exit, str(ph.exit_timer), str(ph.signal_timeout),
				U.rid(ph.physical_move), str(ph.check_landing), str(ph.invulnerable), ph.frame_events.size()])
			for j in ph.frame_events.size():
				var e: FrameEvent = ph.frame_events[j]
				_emit("DAT|act=%s|ph=%s|ev=%d|fr=%d|type=%d:%s|val=%s|part=%s|fx=%s|obj=%s" % [
					item["name"], pair[0], j, e.frame, e.type, U.type_name(e.type), e.value,
					U.rid(e.particle_def), U.rid(e.fx_resource), U.rid(e.spawn_object)])


## Auto-verificação: o harness realmente alcança tudo o que promete proteger.
func _chk_harness() -> void:
	_expect("CHK/actions_found", _actions.size() > 0, "ações=%d" % _actions.size())
	_expect("CHK/events_found", _all_events.size() > 0, "eventos=%d" % _all_events.size())
	var missing: Array[String] = []
	for id in _all_events:
		if not _fired.has(id):
			missing.append(String(_all_events[id]))
	_expect("CHK/every_frame_event_fired_at_least_once", missing.is_empty(),
		"nunca disparou: %s" % str(missing) if not missing.is_empty() else "eventos=%d" % _all_events.size())
	var timeouts: int = 0
	for l in _lines:
		if l.contains("END|result=TIMEOUT"):
			timeouts += 1
	_expect("CHK/no_action_hit_tick_limit", timeouts == 0, "timeouts=%d" % timeouts)

	# A comparação com o baseline não pode estar cega (grupos vazios = "diff vazio" falso).
	var empty_groups: Array[String] = []
	for sid in _order:
		if String(_groups[sid]["tag"]) == "REG" and _only_trace(_groups[sid]["lines"]).is_empty():
			empty_groups.append(sid)
	_expect("CHK/every_reg_group_has_trace_lines", empty_groups.is_empty(),
		"grupos vazios: %s" % str(empty_groups) if not empty_groups.is_empty() else "grupos=%d" % _order.size())
	var parsed: Dictionary = _parse_groups("\n".join(_lines) + "\n")
	var mismatch: Array[String] = []
	for sid in _order:
		if String(_groups[sid]["tag"]) != "REG":
			continue
		if not parsed.has(sid) or _only_trace(parsed[sid]) != _only_trace(_groups[sid]["lines"]):
			mismatch.append(sid)
	_expect("CHK/parse_roundtrip_matches_memory", mismatch.is_empty(),
		"divergem: %s" % str(mismatch) if not mismatch.is_empty() else "ok")


# ============================================================
# Saída e comparação com o baseline
# ============================================================

func _finish() -> void:
	var path := "user://hitbox_%s.txt" % label
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	print("")
	print("HITBOX harness [%s]" % label)
	print("HITBOX harness — log: %s" % ProjectSettings.globalize_path(path))
	print("HITBOX harness — ações=%d  eventos=%d  cenários=%d" % [_actions.size(), _all_events.size(), _order.size()])
	print("HITBOX harness — ASSERT: PASS=%d FAIL=%d" % [_pass, _fail])
	if label != BASELINE_LABEL:
		_compare_with_baseline()


func _compare_with_baseline() -> void:
	var bpath := "user://hitbox_%s.txt" % BASELINE_LABEL
	if not FileAccess.file_exists(bpath):
		print("HITBOX harness — sem baseline em %s (rode primeiro com label = baseline)." % ProjectSettings.globalize_path(bpath))
		return
	var base := _parse_groups(FileAccess.get_file_as_string(bpath))
	var diffs: int = 0
	for sid in _order:
		if String(_groups[sid]["tag"]) != "REG":
			continue
		if not base.has(sid):
			print("HITBOX harness — cenário [REG] novo, sem baseline: %s (ignorado)" % sid)
			continue
		var cur: Array = _only_trace(_groups[sid]["lines"])
		var ref: Array = _only_trace(base[sid])
		if cur != ref:
			diffs += 1
			print("REGRESSÃO em %s:" % sid)
			_print_first_diff(ref, cur)
	for sid in base:
		if sid.begins_with("REG_") and not _groups.has(sid):
			diffs += 1
			print("REGRESSÃO: cenário do baseline sumiu: %s" % sid)
	if diffs == 0:
		print("HITBOX harness — REGRESSÃO: diff vazio (todos os cenários [REG] idênticos ao baseline).")
	else:
		print("HITBOX harness — REGRESSÃO: %d cenário(s) divergem do baseline." % diffs)


func _print_first_diff(ref: Array, cur: Array) -> void:
	var n: int = maxi(ref.size(), cur.size())
	for i in n:
		var a: String = ref[i] if i < ref.size() else "<fim>"
		var b: String = cur[i] if i < cur.size() else "<fim>"
		if a != b:
			print("  linha %d" % (i + 1))
			print("  baseline: %s" % a)
			print("  atual   : %s" % b)
			return


func _only_trace(lines: Array) -> Array:
	var out: Array = []
	for l in lines:
		for p in TRACE_PREFIXES:
			if l.begins_with(p):
				out.append(l)
				break
	return out


func _parse_groups(text: String) -> Dictionary:
	var res := {}
	var cur := ""
	for l in text.split("\n"):
		if l.begins_with("=== "):
			cur = l.substr(4).split(" [")[0]
			res[cur] = []
		elif cur != "" and l != "":
			var arr: Array = res[cur]
			arr.append(l)
	return res
