extends Node2D
## [STATES · BATCH 0 — VALIDAÇÃO TEMPORÁRIA — remover ao fim da tarefa de States]
##
## Baseline de comportamento da StateMachine do Player e dos States do recorte (movimento).
## NÃO testa nada novo: congela o que já funciona, para que as próximas mudanças (lote A4b de
## correções, resolvedor de intenção, migração da fatia 1) provem que não quebraram nada.
## Mesmo molde do HitboxBaseline / harness da A2.
##
## COMO USAR
##   1. Copie esta pasta para res://_states_validation/ e rode StatesBaseline.tscn (F6).
##      Também roda por linha de comando:
##        godot --headless --path . res://_states_validation/StatesBaseline.tscn -- label=baseline
##   2. O resultado aparece no Output e em user://states_<label>.txt (o caminho é impresso).
##   3. BASELINE: rode ANTES de qualquer mudança de código (label = baseline).
##      Depois de cada lote, mude o label no Inspector (ex.: a4b) e rode de novo: o harness
##      compara sozinho os cenários [REG] com o baseline e imprime o diff.
##      NUNCA regenere o baseline depois de mudar código: isso esconderia a regressão.
##
##   [REG]  regressão: o transcript tem que ser IDÊNTICO ao baseline, ou igual ao arquivo
##          states_<label>_esperado.txt do lote (as mudanças que o lote DECLAROU e que foram
##          revisadas). Qualquer outra diferença é REGRESSÃO. Sem esse arquivo, toda mudança é regressão.
##   [CHK]  auto-verificação do próprio harness: deve dar PASS já no baseline.
##
## O QUE É OBSERVADO (o contrato que os lotes não podem alterar sem avisar)
##   EVT  cada State em que o jogador entra (com posição/velocidade) e um snapshot a cada 10 ticks.
##   ACT  cada chamada na fronteira: StateMachine.change_state (com aninhamento), VisualLibrary
##        (play_state / set_anim_level), FXComponent, Player.change_animation_set.
##   END  como o cenário terminou.
##   DAT  o grafo ESTÁTICO de transições (change_state("X") de cada script de State) e a config.
##
## COMO É DETERMINÍSTICO
##   O Player é um FakePlayer (extends Player) SEM a _ready() do pai, com os States REAIS da
##   player.tscn. Física em ticks fixos (physics_frame), input injetado por Input.action_press,
##   relógio do InputManager conduzido à mão (_process(DT)), animação do Sprite avançada à mão.
##   O modo de input é reafirmado a cada tick (o boot do GameManager o derruba 0,5 s após iniciar).
##   Sem arte: SpriteFrames sintético, dados de personagem/armadura sintéticos (assim o resultado
##   não depende de quais assets existem na máquina). Sem sorteio, sem relógio.
##
## PONTOS DE OBSERVAÇÃO (se um lote mover algo daqui, este é o único lugar a adaptar)
##   TracedSM sobrescreve StateMachine.change_state só para registrar e chama o original (super).
##   SpyVL / SpyFX substituem VisualLibrary / FXComponent só para registrar as chamadas.
##   FakePlayer._process_state replica o Player._process_state SEM ArmorManager.sync_frame.

@export var label: String = "baseline"

## Passo de física do projeto (o relógio do InputManager é conduzido com ele).
var DT: float = 1.0 / float(Engine.physics_ticks_per_second)

const BASELINE_LABEL: String = "baseline"
const FLOOR_Y: float = 200.0
const FEET: float = 22.0            # distância origem do Player -> pés (feet_offset_y padrão)
const ANIM_TICKS: int = 30          # duração das animações não-loop do Sprite falso
const SETTLE_TICKS: int = 4         # ticks para o Player assentar no chão antes do cenário
const STATES_DIR: String = "res://player/states"
const EXPECTED_DIR: String = "res://_states_validation"
const INTRO_SCRIPT: String = "res://player/intro.gd"
const SNAP_EVERY: int = 10
const TRACE_PREFIXES: Array[String] = ["EVT|", "ACT|", "END|", "DAT|"]
const LOOPING_ANIMS: Array[String] = ["idle", "walk", "run", "fall", "hover"]
const ALL_ANIMS: Array[String] = ["idle", "walk", "run", "fall", "hover", "jump", "jumptoidle",
		"land", "dash", "airdash", "wallkick", "wallslide", "shoot", "equip", "attack1", "unequip"]
const ACTIONS: Array[String] = ["move_left", "move_right", "jump", "shoot", "dash"]


# ============================================================
# Espiões e ator falso
# ============================================================

## VisualLibrary falso: só registra (e imita o efeito mínimo no Sprite: toca a animação de mesmo nome).
class SpyVL extends "res://autoload/VisualLibrary.gd":
	var sink: Callable = Callable()
	var host: Node2D = null

	func play_state(state_name: String) -> void:
		if sink.is_valid():
			sink.call("ACT", "vl.play_state|name=%s" % state_name)
		_mimic(state_name.to_lower())

	func set_anim_level(state_name: String, level: int) -> void:
		if sink.is_valid():
			sink.call("ACT", "vl.set_anim_level|state=%s|level=%d" % [state_name, level])

	func _mimic(anim: String) -> void:
		var s: AnimatedSprite2D = host.get("sprite") as AnimatedSprite2D
		if s and s.sprite_frames and s.sprite_frames.has_animation(anim):
			s.play(anim)


## FXComponent falso: só registra.
class SpyFX extends FXComponent:
	var sink: Callable = Callable()
	var _last_level: Dictionary = {}

	func _log(body: String) -> void:
		if sink.is_valid():
			sink.call("ACT", body)

	func start(fx_name: String) -> void:
		_log("fx.start|name=%s" % fx_name)

	func stop(fx_name: String) -> void:
		_last_level.erase(fx_name)
		_log("fx.stop|name=%s" % fx_name)

	## O Hover chama set_level todo tick (idempotente): só registra quando o valor MUDA.
	func set_level(fx_name: String, level: int, facing_right: bool = true) -> void:
		var key: String = "%d|%s" % [level, str(facing_right)]
		if _last_level.get(fx_name, "") == key:
			return
		_last_level[fx_name] = key
		_log("fx.set_level|name=%s|level=%d|right=%s" % [fx_name, level, str(facing_right)])

	func set_stationary_position(fx_name: String, _pos: Vector2) -> void:
		_log("fx.set_stationary_position|name=%s" % fx_name)

	func get_stationary(fx_name: String) -> StationaryFX:
		_log("fx.get_stationary|name=%s" % fx_name)
		return null


## StateMachine real + registro de cada change_state (inclusive os aninhados).
class TracedSM extends StateMachine:
	var sink: Callable = Callable()

	func change_state(new_state_name: String) -> void:
		var from_name: String = current_state_name
		if sink.is_valid():
			sink.call("ACT", "sm.change_state|req=%s|from=%s" % [new_state_name, from_name])
		super.change_state(new_state_name)
		if sink.is_valid():
			sink.call("ACT", "sm.done|req=%s|cur=%s" % [new_state_name, current_state_name])


## Player real (Player.gd) sem a _ready() do pai (que carregaria personagem, intro, HUD...).
class FakePlayer extends Player:
	var sink: Callable = Callable()

	func _ready() -> void:
		pass   # de propósito: a _ready() do Player não roda; o harness monta tudo à mão

	## Igual ao Player._process_state, SEM ArmorManager.sync_frame (visual de armadura).
	func _process_state(delta: float) -> void:
		if state_machine:
			state_machine.process_state(delta)
		wall_slide_cooldown = maxf(0.0, wall_slide_cooldown - delta)
		wall_kick_grace = maxf(0.0, wall_kick_grace - delta)

	## Sem carregar arte: só registra.
	func change_animation_set(action: String) -> void:
		if sink.is_valid():
			sink.call("ACT", "player.change_animation_set|action=%s" % action)


## Intenção roteirizada: o harness decide o que o jogador "quer", sem Input real.
class ScriptedIntent extends PlayerIntent:
	var direction: float = 0.0
	var jump: bool = false
	var dash: bool = false
	var attack: bool = false
	var special: bool = false

	func move_direction() -> float: return direction
	func wants_jump() -> bool: return jump
	func wants_dash() -> bool: return dash
	func wants_attack() -> bool: return attack
	func wants_special_weapon() -> bool: return special


# ============================================================
# Estado do harness
# ============================================================

var _lines: PackedStringArray = []
var _order: Array[String] = []
var _groups: Dictionary = {}
var _sid: String = ""
var _tick: int = 0
var _pass: int = 0
var _fail: int = 0
var _world: Node2D = null
var _last_state: String = ""
var _seen: Array[String] = []              # "A>B" de todas as transições observadas
var _anim_ticks: int = 0
var _last_anim: String = ""
var _last_playing: bool = false
var _saved: Dictionary = {}
var _tl: Array = []                        # linha do tempo observada do último _sim: [[tick, estado], ...]
var _tl_end: int = 0                       # nº de ticks do último _sim
var _held: Dictionary = {}                 # ações que o HARNESS mantém pressionadas (para vigiar interferência externa)
var _drift: Array[String] = []             # ocorrências em que o Input discordou do que o harness fez
var _drift_seen: Dictionary = {}           # (cenário|ação) já relatado, para não repetir
var _focus_lost: int = 0                   # vezes em que a janela perdeu o foco durante a execução
var _regressions: int = 0                  # regressões da comparação com o baseline (para o resultado geral)
var _input_flips: int = 0                  # vezes em que o modo de input foi derrubado de fora (boot do jogo)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("label="):
			label = a.substr(6)
	_save_env()
	get_window().focus_exited.connect(func() -> void: _focus_lost += 1)
	await get_tree().physics_frame
	await _run_all()
	_finish()
	_restore_env()
	get_tree().quit()


# ============================================================
# Infra (mesmo molde do HitboxBaseline)
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
	await get_tree().physics_frame


func _expect(test_name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
	var line := "ASSERT|%s|%s|%s" % [test_name, "PASS" if cond else "FAIL", detail]
	_lines.append(line)
	print(line)


func _clean() -> void:
	for a in ACTIONS:
		_release(a)
	InputManager.shoot_buffer = 0.0
	InputManager.jump_buffer = 0.0
	if is_instance_valid(_world):
		_world.queue_free()
	_world = null


## O harness mexe em estado global (autoloads, Input): guarda e devolve no fim.
func _save_env() -> void:
	_saved = {
		"mode": GameManager.current_input_mode,
		"can": InputManager.can_process_player_input,
		"player": GameManager.current_player,
		"im_process": InputManager.is_processing(),
	}


func _restore_env() -> void:
	for a in ACTIONS:
		Input.action_release(a)
	GameManager.current_input_mode = _saved["mode"]
	InputManager.can_process_player_input = _saved["can"]
	GameManager.current_player = _saved["player"]
	InputManager.set_process(_saved["im_process"])


# ============================================================
# Montagem do mundo e do Player falso
# ============================================================

func _new_world() -> Node2D:
	var w := Node2D.new()
	w.name = "World"
	add_child(w)
	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	var shp := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8000.0, 40.0)
	shp.shape = rect
	floor_body.add_child(shp)
	floor_body.position = Vector2(0.0, FLOOR_Y + 20.0)   # topo do chão em FLOOR_Y
	w.add_child(floor_body)
	return w


func _make_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for a in ALL_ANIMS:
		sf.add_animation(a)
		sf.set_animation_loop(a, LOOPING_ANIMS.has(a))
		sf.set_animation_speed(a, 12.0)
		var tex := PlaceholderTexture2D.new()
		for i in 6:
			sf.add_frame(a, tex)
	return sf


func _make_character(char_id: String) -> PlayerCharacterData:
	var c := PlayerCharacterData.new()
	c.character_id = StringName(char_id)
	c.default_weapon = "saber" if char_id == "Zero" else "buster"
	if char_id == "Zero":
		var atk := AttackData.new()          # 1 golpe: attack1 -> unequip (dados sintéticos)
		atk.set_name = "attack"
		atk.animation_name = "attack1"
		atk.unequip_animation = "unequip"
		atk.unlocked = true
		var tree := SkillTree.new()
		tree.basic_combo.append(atk)
		c.skill_tree = tree
	return c


func _make_armor(flags: Dictionary) -> ArmorData:
	var a := ArmorData.new()
	a.has_air_dash = bool(flags.get("air_dash", true))
	a.has_double_jump = bool(flags.get("double_jump", false))
	a.can_wall_kick = bool(flags.get("wall_kick", true))
	return a


## Monta o FakePlayer com os States REAIS da player.tscn (exports já configurados na cena).
func _build_player(char_id: String, armor_flags: Dictionary) -> FakePlayer:
	var scene: PackedScene = load("res://player/player.tscn")
	var real: Node = scene.instantiate()

	var p := FakePlayer.new()
	p.name = "Player"
	for k in ["ground_acceleration", "max_fall_speed", "speed", "dash_speed", "jump_velocity",
			"gravity", "air_control_multiplier", "air_acceleration", "jump_gravity_multiplier",
			"fall_gravity_multiplier", "collision_layer", "collision_mask"]:
		p.set(k, real.get(k))

	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = _make_frames()
	spr.process_mode = Node.PROCESS_MODE_DISABLED   # os frames são avançados à mão
	p.add_child(spr)
	for n in ["ArmorLayerHead", "ArmorLayerBody", "ArmorLayerArms", "ArmorLayerLegs"]:
		var layer := AnimatedSprite2D.new()
		layer.name = n
		p.add_child(layer)
	for n in ["ArmBaseLayer", "BusterLayer", "ChargeSystem"]:
		var plain := Node.new()
		plain.name = n
		p.add_child(plain)
	for n in ["SpawnRight_idle", "SpawnLeft_idle", "SpawnRight_walk", "SpawnLeft_walk"]:
		var mk := Marker2D.new()
		mk.name = n
		p.add_child(mk)

	var ray := RayCast2D.new()
	ray.name = "WallRay"
	var real_ray: RayCast2D = real.get_node_or_null("WallRay") as RayCast2D
	if real_ray:
		ray.target_position = real_ray.target_position
		ray.collision_mask = real_ray.collision_mask
		ray.enabled = real_ray.enabled
	p.add_child(ray)

	var col := CollisionShape2D.new()
	col.name = "BodyCollision"
	var body := RectangleShape2D.new()
	body.size = Vector2(20.0, 32.0)
	col.shape = body
	col.position = Vector2(0.0, FEET - 16.0)
	p.add_child(col)

	var vl := SpyVL.new()
	vl.name = "VisualLibrary"
	vl.sink = _sink
	vl.host = p
	p.add_child(vl)

	var fx := SpyFX.new()
	fx.name = "FXComponent"
	fx.sink = _sink
	p.add_child(fx)

	var sm := TracedSM.new()
	sm.name = "StateMachine"
	sm.sink = _sink
	p.add_child(sm)
	var real_sm: Node = real.get_node("StateMachine")
	for c in real_sm.get_children():
		real_sm.remove_child(c)
		c.owner = null    # o owner apontava para a raiz da cena instanciada (descartada)
		sm.add_child(c)
	real.free()

	# FX do Dash são dado de arte: troca por defs vazios (sem sprite_frames não spawnam nada).
	var dash_node: Node = sm.get_node_or_null("Dash")
	if dash_node:
		dash_node.set("dash_spark_def", SpawnedParticleDef.new())
		var smoke := SpawnedParticleDef.new()
		smoke.marker_path = "SpawnRight_walk"
		dash_node.set("dash_smoke_def", smoke)

	p.sink = _sink
	p.current_character = _make_character(char_id)
	p.current_armor = _make_armor(armor_flags)
	return p


# ============================================================
# Simulação de um cenário
# ============================================================

func _press(action: String) -> void:
	_held[action] = true
	Input.action_press(action)


func _release(action: String) -> void:
	_held[action] = false
	Input.action_release(action)


## O harness sabe o que pressionou. Se o Input discorda (tecla, mouse ou controle reais, ou troca de
## foco da janela), o cenário foi CONTAMINADO: relata, sem corrigir (re-pressionar criaria um
## just_pressed que o cenário não tem). Só a 1ª ocorrência por cenário e ação é guardada.
func _check_input_drift() -> void:
	for a in ACTIONS:
		var want: bool = bool(_held.get(a, false))
		if Input.is_action_pressed(a) == want:
			continue
		var key: String = "%s|%s" % [_sid, a]
		if _drift_seen.has(key):
			continue
		_drift_seen[key] = true
		_drift.append("%s: '%s' %s de fora no tick %d" % [_sid, a, "liberada" if want else "pressionada", _tick])


func _kin(h: FakePlayer) -> String:
	return "floor=%s|px=%.2f|py=%.2f|vx=%.3f|vy=%.3f|face=%s|anim=%s|playing=%s" % [
		str(h.is_on_floor()), h.global_position.x, h.global_position.y, h.velocity.x, h.velocity.y,
		"R" if h.facing_right else "L", String(h.sprite.animation), str(h.sprite.is_playing())]


func _observe(h: FakePlayer) -> void:
	var cur: String = h.state_machine.current_state_name
	if cur != _last_state:
		_seen.append("%s>%s" % [_last_state, cur])
		_tl.append([_tick, cur])
		_sink("EVT", "state=%s|prev=%s|%s" % [cur, _last_state, _kin(h)])
		_last_state = cur
	elif _tick > 0 and _tick % SNAP_EVERY == 0:
		_sink("EVT", "snap|state=%s|%s" % [cur, _kin(h)])


## Avança o Sprite falso 1 tick: não-loop termina após ANIM_TICKS (is_playing() vira false).
func _step_sprite(h: FakePlayer) -> void:
	var s: AnimatedSprite2D = h.sprite
	if s.is_playing():
		if String(s.animation) != _last_anim or not _last_playing:
			_anim_ticks = 0
		else:
			_anim_ticks += 1
		if _anim_ticks >= ANIM_TICKS and not s.sprite_frames.get_animation_loop(String(s.animation)):
			s.pause()
	_last_anim = String(s.animation)
	_last_playing = s.is_playing()


func _apply_events(events: Array, tick: int, h: FakePlayer) -> void:
	for e in events:
		if int(e[0]) != tick:
			continue
		match String(e[1]):
			"press":
				_press(String(e[2]))
			"release":
				_release(String(e[2]))
			"do":
				(e[2] as Callable).call(h)


## spec: char, armor{}, height (px acima do chão), start (State inicial), ticks, events [[tick,tipo,arg]],
##       setup (Callable(h) opcional, roda depois do initialize e antes do State inicial).
func _sim(spec: Dictionary) -> FakePlayer:
	var char_id: String = String(spec.get("char", "X"))
	var height: float = float(spec.get("height", 0.0))
	GameManager.current_player = char_id
	GameManager.current_input_mode = GameManager.InputMode.PLAYER
	InputManager.can_process_player_input = true
	InputManager.set_process(false)           # relógio do InputManager conduzido à mão
	InputManager.shoot_buffer = 0.0
	InputManager.jump_buffer = 0.0
	for a in ACTIONS:
		_release(a)

	_world = _new_world()
	var h: FakePlayer = _build_player(char_id, spec.get("armor", {}))
	_world.add_child(h)
	h.global_position = Vector2(0.0, FLOOR_Y - FEET - height)

	if height <= 0.0:
		for i in SETTLE_TICKS:
			await get_tree().physics_frame      # assenta no chão (sem State ativo: process_state é no-op)
	h.velocity = Vector2.ZERO

	_tick = 0
	_tl = []
	_tl_end = int(spec.get("ticks", 60))
	_last_state = ""
	_anim_ticks = 0
	_last_anim = ""
	_last_playing = false
	h.state_machine.initialize(h)
	_emit("DAT|char=%s|armor=%s|height=%s|start=%s|ticks=%d" % [
		char_id, str(spec.get("armor", {})), str(height), String(spec.get("start", "Idle")), int(spec.get("ticks", 60))])
	if spec.has("setup"):
		(spec["setup"] as Callable).call(h)
	h.state_machine.change_state(String(spec.get("start", "Idle")))
	_observe(h)

	var events: Array = spec.get("events", [])
	var ticks: int = int(spec.get("ticks", 60))
	for i in ticks:
		await get_tree().physics_frame
		_observe(h)                              # resultado do tick anterior
		_tick = i + 1
		_apply_events(events, _tick, h)
		_pin_input_mode()                        # o boot do jogo (GameManager) pode derrubar o modo de input
		_check_input_drift()
		InputManager._process(DT)
		_step_sprite(h)
	await get_tree().physics_frame
	_observe(h)
	_emit("END|ticks=%d|state=%s|%s" % [ticks, h.state_machine.current_state_name, _kin(h)])
	h.set_physics_process(false)               # congela: a limpeza do cenário não gera ticks extras
	return h


## GameManager._ready() chama start_game_flow(): 0,5 s depois do boot o jogo vai para PLAYER_SELECT,
## o que põe o modo de input em MENU e can_process_player_input em false. Esse timer corre em
## paralelo ao harness (corrida entre o boot e o 1º cenário). Reafirmar o modo a cada tick faz
## o resultado independer de QUANDO o timer dispara.
func _pin_input_mode() -> void:
	if GameManager.current_input_mode != GameManager.InputMode.PLAYER or not InputManager.can_process_player_input:
		_input_flips += 1                        # só diagnóstico (console); não entra no transcript
	GameManager.current_input_mode = GameManager.InputMode.PLAYER
	InputManager.can_process_player_input = true


func _spec_run(spec: Dictionary) -> void:
	await _sim(spec)


# ============================================================
# Cenários
# ============================================================

func _run_all() -> void:
	await _scenario("REG_data_graph", "REG", _reg_data_graph)

	# -- movimento básico ----------------------------------------------------------------
	await _scenario("REG_idle_run_idle", "REG", _spec_run.bind(_spec_idle_run_idle()))
	await _scenario("REG_fall_land_idle", "REG", _spec_run.bind({"height": 60.0, "start": "Fall", "ticks": 90}))
	await _scenario("REG_fall_land_run", "REG", _spec_run.bind({"height": 60.0, "start": "Fall", "ticks": 90,
		"events": [[1, "press", "move_right"]]}))
	await _scenario("REG_jump_land", "REG", _spec_run.bind({"ticks": 120,
		"events": [[5, "press", "jump"], [20, "release", "jump"]]}))

	# -- Dash (fim do Dash: Idle / Run / Fall; achado 9) --------------------------------
	await _scenario("REG_dash_ground_no_dir", "REG", _spec_run.bind({"ticks": 90,
		"events": [[5, "press", "dash"], [6, "release", "dash"]]}))
	await _scenario("REG_dash_ground_with_dir", "REG", _spec_run.bind({"ticks": 90,
		"events": [[3, "press", "move_right"], [5, "press", "dash"], [6, "release", "dash"]]}))
	await _scenario("REG_dash_to_jump", "REG", _spec_run.bind({"ticks": 90,
		"events": [[5, "press", "dash"], [6, "release", "dash"], [12, "press", "jump"], [14, "release", "jump"]]}))
	# Dash.gd:47 tem uma chamada a AirDash, mas AirDash é um State INDEPENDENTE (dash aéreo da
	# armadura). Este cenário só alcança esse ramo FORÇANDO o Dash para fora do chão (teleporte).
	await _scenario("REG_dash_branch_to_airdash_forced", "REG", _spec_run.bind({"ticks": 90,
		"events": [[5, "press", "dash"], [6, "release", "dash"],
			[10, "do", func(h: FakePlayer) -> void: h.global_position.y -= 40.0],
			[12, "press", "dash"], [13, "release", "dash"]]}))

	# Achado 9 (Dash.gd:47 sem return): só tem efeito se o dash_timer zerar no MESMO frame em que o
	# AirDash é acionado. Hoje o Dash.update continua e troca o AirDash por Fall na hora; com o
	# return, o AirDash permanece. É o cenário que torna o conserto observável.
	await _scenario("REG_dash_branch_airdash_same_frame_timer_end", "REG", _spec_run.bind({"ticks": 60,
		"events": [[5, "press", "dash"], [6, "release", "dash"],
			[8, "do", func(h: FakePlayer) -> void: h.global_position.y -= 40.0],   # is_on_floor() só muda no próximo move_and_slide
			[9, "press", "dash"],                                                  # o input injetado no tick N é visto pelo Player no passo N+1
			[10, "do", func(h: FakePlayer) -> void: h.state_machine.states["Dash"].dash_timer = 0.0],
			[10, "release", "dash"]]}))

	# -- AirDash: as ENTRADAS REAIS (Jump.gd:39, Fall.gd:68) e o que acontece ao terminar --------
	await _scenario("REG_airdash_from_jump", "REG", _spec_run.bind({"ticks": 100,
		"events": [[5, "press", "jump"], [8, "release", "jump"], [15, "press", "dash"], [16, "release", "dash"]]}))
	await _scenario("REG_airdash_from_fall", "REG", _spec_run.bind({"start": "Fall", "height": 90.0, "ticks": 100,
		"events": [[5, "press", "dash"], [6, "release", "dash"]]}))
	# Direção contrária durante e depois do AirDash: congela o comportamento ATUAL (sem freio de
	# momentum). A política de freio é decisão futura: vai aparecer aqui como diff declarado.
	await _scenario("REG_airdash_opposite_input", "REG", _spec_run.bind({"ticks": 110,
		"events": [[5, "press", "jump"], [8, "release", "jump"], [15, "press", "dash"], [16, "release", "dash"],
			[22, "press", "move_left"], [90, "release", "move_left"]]}))

	# -- Hover (X com double jump) -------------------------------------------------------
	await _scenario("REG_hover_double_jump", "REG", _spec_run.bind({"armor": {"double_jump": true}, "ticks": 160,
		"setup": func(h: FakePlayer) -> void: h.can_double_jump = true,   # (o Land.enter é quem habilita no jogo)
		"events": [[5, "press", "jump"], [8, "release", "jump"], [20, "press", "jump"], [70, "release", "jump"],
			[35, "press", "move_right"], [55, "release", "move_right"], [60, "press", "move_left"], [68, "release", "move_left"]]}))

	# -- Visual: quantas vezes cada State entra e quantas vezes o play_state é chamado ----
	for st in ["Idle", "Run", "Jump", "Fall", "Land", "Dash", "AirDash", "WallSlide", "WallKick", "Hover"]:
		var grounded: bool = st in ["Idle", "Run", "Dash", "Land"]
		var spec: Dictionary = {"start": st, "ticks": 6, "armor": {"double_jump": true}}
		if not grounded:
			spec["height"] = 80.0
		await _scenario("REG_enter_%s" % st, "REG", _spec_run.bind(spec))

	# -- Re-entrância: State que troca de State dentro do enter() ------------------------
	await _scenario("REG_nested_wallslide_to_wallkick", "REG", _spec_run.bind({"start": "WallSlide", "height": 80.0, "ticks": 6,
		"setup": func(_h: FakePlayer) -> void: InputManager.jump_buffer = InputManager.jump_buffer_time}))

	# -- Legado (SaberAttack/SaberUnequip) e ramo morto (SaberAttackAir fora da cena) -----
	await _scenario("REG_zero_saber_ground", "REG", _spec_run.bind({"char": "Zero", "ticks": 120,
		"events": [[5, "press", "shoot"], [6, "release", "shoot"]]}))
	await _scenario("REG_zero_air_attack_dead_branch", "REG", _spec_run.bind({"char": "Zero", "ticks": 60,
		"events": [[5, "press", "jump"], [8, "release", "jump"], [20, "press", "shoot"], [21, "release", "shoot"]]}))

	# -- Resolvedor de intenção (A5): cenários NEW, com a expectativa calculada AQUI --------
	if _resolver_available():
		await _scenario("NEW_resolver_ground_no_direction", "NEW", _resolver_case.bind("ground_no_direction", {}, "", ["Idle"], "Idle"))
		await _scenario("NEW_resolver_ground_with_direction", "NEW", _resolver_case.bind("ground_with_direction", {}, "move_right", ["Run"], "Run"))
		await _scenario("NEW_resolver_air_falling", "NEW", _resolver_case.bind("air_falling", {"height": 40.0, "vy": 50.0}, "", ["Fall"], "Fall"))
		await _scenario("NEW_resolver_air_rising", "NEW", _resolver_case.bind("air_rising", {"height": 40.0, "vy": -120.0}, "", ["Fall"], "Fall"))
		await _scenario("NEW_resolver_air_with_direction", "NEW", _resolver_case.bind("air_with_direction", {"height": 40.0, "vy": 50.0}, "move_right", ["Fall"], "Fall"))
		await _scenario("NEW_resolver_unknown_intent", "NEW", _resolver_unknown)
	else:
		print("STATES harness — nota: StateMachine.request() não existe (árvore anterior ao A5); cenários NEW do resolvedor ignorados.")

	# -- Land (22/11): sai sozinho; qualquer intenção o interrompe ----------------------
	if _land_fix_available():
		await _scenario("NEW_land_no_intention_completes_then_idle", "NEW", _land_no_intention)
		await _scenario("NEW_land_residual_speed_does_not_stick", "NEW", _land_residual_speed)
		await _scenario("NEW_land_move_intention_at_landing", "NEW", _land_intention_at_landing)
		await _scenario("NEW_land_move_intention_mid_land", "NEW", _land_mid.bind("move_intention", [[15, "press", "move_right"]], "Run", "X"))
		await _scenario("NEW_land_jump_intention_mid_land", "NEW", _land_mid.bind("jump_intention", [[15, "press", "jump"], [16, "release", "jump"]], "Jump", "X"))
		await _scenario("NEW_land_dash_intention_mid_land", "NEW", _land_mid.bind("dash_intention", [[15, "press", "dash"], [16, "release", "dash"]], "Dash", "X"))
		await _scenario("NEW_land_attack_intention_mid_land", "NEW", _land_mid.bind("attack_intention", [[15, "press", "shoot"], [16, "release", "shoot"]], "SaberAttack", "Zero"))
		await _scenario("NEW_land_safety_timeout_when_animation_never_ends", "NEW", _land_safety_timeout)
	else:
		print("STATES harness — nota: o Land desta árvore é anterior à correção (sem safety_timeout); cenários NEW do Land ignorados.")

	# -- Interface de intenção (B3, fatia 1): PlayerIntent ---------------------------------
	await _scenario("NEW_intent_default_follows_real_input", "NEW", _intent_default)
	await _scenario("NEW_intent_has_intent_covers_every_question", "NEW", _intent_has_intent)
	await _scenario("NEW_intent_resolver_scripted_run", "NEW", _intent_resolver.bind("scripted_run", 1.0, "", 0.0, ["Run"]))
	await _scenario("NEW_intent_resolver_ignores_real_input", "NEW", _intent_resolver.bind("scripted_idle_real_pressed", 0.0, "move_right", 0.0, ["Idle"]))
	await _scenario("NEW_intent_resolver_air_is_fall", "NEW", _intent_resolver.bind("scripted_air", 1.0, "", 40.0, ["Fall"]))
	await _scenario("NEW_intent_land_interrupted_by_scripted_intent", "NEW", _intent_land_scripted)
	await _scenario("NEW_intent_land_ignores_real_input_when_scripted", "NEW", _intent_land_ignores_real)

	await _scenario("CHK_determinism_a", "CHK", _spec_run.bind(_spec_idle_run_idle()))
	await _scenario("CHK_determinism_b", "CHK", _spec_run.bind(_spec_idle_run_idle()))
	await _scenario("CHK_harness", "CHK", _chk_harness)


## O resolvedor existe nesta árvore? (permite rodar o mesmo harness em árvores anteriores ao A5)
func _resolver_available() -> bool:
	var m := StateMachine.new()
	var ok: bool = m.has_method("request")
	m.free()
	return ok


## Um contexto do resolvedor. Confere (1) QUEM responde à intenção, em conjunto: tem que ser exatamente
## o esperado (exclusividade; o Jump nunca entra) e (2) para onde a troca vai.
## O pedido é feito no tick 1, antes de qualquer update de State, para o contexto não mudar sozinho.
func _resolver_case(case_id: String, extra: Dictionary, press: String, expect_answering: Array, expect_state: String) -> void:
	var out: Dictionary = {}
	var events: Array = []
	if press != "":
		events.append([1, "press", press])
	events.append([1, "do", func(h: FakePlayer) -> void:
		h.velocity.y = float(extra.get("vy", 0.0))
		var sm: StateMachine = h.state_machine
		var answering: Array = []
		for n in sm.states:
			if sm.states[n].can_resolve(Intents.RESUME_MOVEMENT):
				answering.append(String(n))
		answering.sort()
		out["answering"] = answering
		out["ret"] = sm.request(Intents.RESUME_MOVEMENT)
		out["state"] = sm.current_state_name])
	var spec: Dictionary = {"start": "Land", "ticks": 3, "events": events}
	if extra.has("height"):
		spec["height"] = extra["height"]
	await _sim(spec)
	_expect("NEW_resolver/%s/who_answers" % case_id, out.get("answering", []) == expect_answering,
		"obtido=%s esperado=%s" % [str(out.get("answering")), str(expect_answering)])
	_expect("NEW_resolver/%s/never_jump" % case_id, not (out.get("answering", []) as Array).has("Jump"))
	_expect("NEW_resolver/%s/resolved_to" % case_id, bool(out.get("ret", false)) and String(out.get("state", "")) == expect_state,
		"ret=%s estado=%s esperado=%s" % [str(out.get("ret")), str(out.get("state")), expect_state])


## Intenção que ninguém atende: não troca de State e devolve false.
func _resolver_unknown() -> void:
	var out: Dictionary = {}
	await _sim({"start": "Land", "ticks": 3, "events": [[1, "do", func(h: FakePlayer) -> void:
		out["before"] = h.state_machine.current_state_name
		out["ret"] = h.state_machine.request(&"nao_existe")
		out["after"] = h.state_machine.current_state_name]]})
	_expect("NEW_resolver/unknown_intent/returns_false", out.get("ret", true) == false)
	_expect("NEW_resolver/unknown_intent/state_unchanged", out.has("before") and out.get("before") == out.get("after"),
		"antes=%s depois=%s" % [str(out.get("before")), str(out.get("after"))])


# -- Land: medidas na linha do tempo -----------------------------------------------------
func _tl_has(state: String) -> bool:
	for e in _tl:
		if e[1] == state:
			return true
	return false


## Quantos ticks o cenário ficou NA primeira ocorrência de `state` (até a próxima mudança).
func _tl_ticks_in(state: String) -> int:
	for i in _tl.size():
		if _tl[i][1] == state:
			var end_tick: int = int(_tl[i + 1][0]) if i + 1 < _tl.size() else _tl_end
			return end_tick - int(_tl[i][0])
	return 0


func _tl_final() -> String:
	return String(_tl[_tl.size() - 1][1]) if not _tl.is_empty() else ""


## Sem nenhuma intenção: a animação de aterrissagem toca inteira e o Land passa o controle sozinho.
func _land_no_intention() -> void:
	await _sim({"height": 60.0, "start": "Fall", "ticks": 120})
	var land: int = _tl_ticks_in("Land")
	_expect("NEW_land/no_intention/animation_plays_fully", land >= ANIM_TICKS - 4 and land <= ANIM_TICKS + 6, "Land durou %d ticks (animação=%d)" % [land, ANIM_TICKS])
	_expect("NEW_land/no_intention/exits_by_itself_to_idle", _tl_final() == "Idle", "estado final=%s" % _tl_final())


## O defeito antigo: sobra velocidade horizontal, sem direção, e o Land nunca saía.
func _land_residual_speed() -> void:
	await _sim({"start": "Land", "ticks": 120, "setup": func(h: FakePlayer) -> void: h.velocity.x = 40.0})
	_expect("NEW_land/residual_speed/does_not_stick", _tl_final() == "Idle", "estado final=%s" % _tl_final())
	_expect("NEW_land/residual_speed/leaves_after_animation", _tl_ticks_in("Land") <= ANIM_TICKS + 6, "Land durou %d ticks" % _tl_ticks_in("Land"))


## Intenção de andar já na aterrissagem: Fall -> Run, com o Land praticamente ignorado.
func _land_intention_at_landing() -> void:
	await _sim({"height": 60.0, "start": "Fall", "ticks": 60, "events": [[1, "press", "move_right"]]})
	_expect("NEW_land/intention_at_landing/reaches_run", _tl_has("Run"))
	_expect("NEW_land/intention_at_landing/land_is_ignored", _tl_ticks_in("Land") <= 2, "Land durou %d ticks" % _tl_ticks_in("Land"))


## Intenção que aparece NO MEIO do Land: ele é interrompido e o estado compatível assume já.
func _land_mid(case_id: String, events: Array, expect_state: String, char_id: String) -> void:
	await _sim({"char": char_id, "start": "Land", "ticks": 60, "events": events})
	_expect("NEW_land/%s/reaches_%s" % [case_id, expect_state], _tl_has(expect_state), "estados vistos=%s" % str(_tl))
	_expect("NEW_land/%s/land_is_interrupted" % case_id, _tl_ticks_in("Land") <= 19, "Land durou %d ticks (a intenção veio no tick 15)" % _tl_ticks_in("Land"))


## Trava de segurança: animação que nunca termina (em loop) não prende o Land.
func _land_safety_timeout() -> void:
	await _sim({"start": "Land", "ticks": 150, "setup": func(h: FakePlayer) -> void:
		h.sprite.sprite_frames.set_animation_loop("land", true)
		h.sprite.sprite_frames.set_animation_loop("jumptoidle", true)})
	var land: int = _tl_ticks_in("Land")
	var limit: int = int(1.0 * Engine.physics_ticks_per_second)
	_expect("NEW_land/safety_timeout/leaves_at_limit", land >= limit - 3 and land <= limit + 6, "Land durou %d ticks (limite=%d)" % [land, limit])
	_expect("NEW_land/safety_timeout/ends_in_idle", _tl_final() == "Idle", "estado final=%s" % _tl_final())


## O Land desta árvore já tem a correção (saída automática)? Permite rodar o harness em árvores anteriores a ela.
func _land_fix_available() -> bool:
	var n: Node = (load("res://player/states/Land.gd") as GDScript).new()
	var ok: bool = "safety_timeout" in n
	n.free()
	return ok


## A fonte padrão da intenção segue o Input real (direção e ação recém-pressionada).
func _intent_default() -> void:
	var out: Dictionary = {}
	await _sim({"ticks": 8, "events": [
		[2, "press", "move_right"],
		[2, "do", func(h: FakePlayer) -> void:
			out["dir_pressed"] = h.intent.move_direction()
			out["has_pressed"] = h.intent.has_intent()],
		[4, "release", "move_right"],
		[4, "do", func(h: FakePlayer) -> void:
			out["dir_released"] = h.intent.move_direction()
			out["has_released"] = h.intent.has_intent()],
		[6, "press", "jump"],
		[7, "do", func(h: FakePlayer) -> void: out["wants_jump"] = h.intent.wants_jump()],   # o just_pressed injetado no tick 6 é visto no 7
		[8, "release", "jump"]]})
	_expect("NEW_intent/default/direction_follows_input", is_equal_approx(float(out.get("dir_pressed", 9.0)), 1.0) and bool(out.get("has_pressed", false)), str(out))
	_expect("NEW_intent/default/released_means_no_intent", is_equal_approx(float(out.get("dir_released", 9.0)), 0.0) and not bool(out.get("has_released", true)), str(out))
	_expect("NEW_intent/default/wants_jump_on_press", bool(out.get("wants_jump", false)), str(out))


## has_intent() é derivada das perguntas: cada uma, sozinha, conta; nenhuma, não conta.
func _intent_has_intent() -> void:
	_expect("NEW_intent/has_intent/none_means_false", not ScriptedIntent.new().has_intent())
	for q in ["direction", "jump", "dash", "attack", "special"]:
		var t := ScriptedIntent.new()
		if q == "direction":
			t.direction = -1.0
		else:
			t.set(q, true)
		_expect("NEW_intent/has_intent/%s_counts" % q, t.has_intent())


## O resolvedor lê a INTERFACE, não o InputManager: com intenção roteirizada, quem responde é o que a
## intenção diz, mesmo com o teclado real dizendo outra coisa.
func _intent_resolver(case_id: String, direction: float, press_real: String, height: float, expect_answering: Array) -> void:
	var out: Dictionary = {}
	var events: Array = []
	if press_real != "":
		events.append([1, "press", press_real])
	events.append([1, "do", func(h: FakePlayer) -> void:
		var answering: Array = []
		for n in h.state_machine.states:
			if h.state_machine.states[n].can_resolve(Intents.RESUME_MOVEMENT):
				answering.append(String(n))
		answering.sort()
		out["answering"] = answering])
	var spec: Dictionary = {"start": "Land", "ticks": 3, "events": events, "setup": func(h: FakePlayer) -> void:
		var si := ScriptedIntent.new()
		si.direction = direction
		h.intent = si}
	if height > 0.0:
		spec["height"] = height
	await _sim(spec)
	_expect("NEW_intent/resolver/%s/who_answers" % case_id, out.get("answering", []) == expect_answering,
		"obtido=%s esperado=%s" % [str(out.get("answering")), str(expect_answering)])


## O Land é interrompido por uma intenção que vem da interface, sem nenhum Input real.
func _intent_land_scripted() -> void:
	await _sim({"start": "Land", "ticks": 40,
		"setup": func(h: FakePlayer) -> void: h.intent = ScriptedIntent.new(),
		"events": [[15, "do", func(h: FakePlayer) -> void: (h.intent as ScriptedIntent).jump = true],
			[16, "do", func(h: FakePlayer) -> void: (h.intent as ScriptedIntent).jump = false]]})
	_expect("NEW_intent/land_scripted/interrupts_land", _tl_ticks_in("Land") <= 19, "Land durou %d ticks (a intenção veio no tick 15)" % _tl_ticks_in("Land"))
	_expect("NEW_intent/land_scripted/ends_outside_land", _tl_final() != "Land", "estado final=%s" % _tl_final())


## E o contrário: com a fonte roteirizada, o Input REAL não interrompe o Land (ele lê a interface).
func _intent_land_ignores_real() -> void:
	await _sim({"start": "Land", "ticks": 60,
		"setup": func(h: FakePlayer) -> void: h.intent = ScriptedIntent.new(),
		"events": [[15, "press", "jump"], [16, "release", "jump"]]})
	_expect("NEW_intent/land_ignores_real/animation_plays_fully", _tl_ticks_in("Land") >= ANIM_TICKS - 4, "Land durou %d ticks" % _tl_ticks_in("Land"))


func _spec_idle_run_idle() -> Dictionary:
	return {"ticks": 120, "events": [[5, "press", "move_right"], [45, "release", "move_right"]]}


## Grafo ESTÁTICO: para cada script de State, os destinos de change_state("X") e quantas vezes.
## Mudar qualquer chamada nominal (migração para intenção) aparece aqui como diff esperado.
func _reg_data_graph() -> void:
	var rx := RegEx.new()
	rx.compile("change_state\\(\\s*\"([A-Za-z0-9_]+)\"\\s*\\)")
	var paths: Array[String] = []
	for f in DirAccess.get_files_at(STATES_DIR):
		if f.ends_with(".gd"):
			paths.append(STATES_DIR.path_join(f))
	paths.append(INTRO_SCRIPT)
	paths.sort()
	for path in paths:
		var counts: Dictionary = {}
		for m in rx.search_all(FileAccess.get_file_as_string(path)):
			var dest: String = m.get_string(1)
			counts[dest] = int(counts.get(dest, 0)) + 1
		var keys: Array = counts.keys()
		keys.sort()
		var parts: PackedStringArray = []
		for k in keys:
			parts.append("%s:%d" % [k, counts[k]])
		_emit("DAT|graph|src=%s|%s" % [path.get_file().get_basename(), ",".join(parts)])
	var sm := StateMachine.new()
	_emit("DAT|special_visual_states|%s" % str(sm.special_visual_states))
	sm.free()


# ============================================================
# Auto-verificação do harness
# ============================================================

func _chk_harness() -> void:
	# Cada transição abaixo tem que ter sido OBSERVADA em algum cenário, senão o baseline
	# estaria protegendo menos do que promete.
	for pair in ["Idle>Run", "Run>Idle", "Fall>Land", "Land>Idle", "Land>Run", "Idle>Jump", "Jump>Fall",
			"Idle>Dash", "Dash>Idle", "Dash>Run", "Dash>Jump", "Jump>AirDash", "Fall>AirDash", "AirDash>Fall",
			"Dash>AirDash", "Jump>Hover", "Idle>SaberAttack"]:
		_expect("CHK/transition_observed/%s" % pair, _seen.has(pair))

	# Mesmo cenário duas vezes tem que dar transcript idêntico (sem sorteio nem relógio).
	var a: Array = _only_trace(_groups["CHK_determinism_a"]["lines"])
	var b: Array = _only_trace(_groups["CHK_determinism_b"]["lines"])
	_expect("CHK/determinism_same_scenario_twice", not a.is_empty() and a == b,
		"linhas=%d/%d" % [a.size(), b.size()])

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
	var path := "user://states_%s.txt" % label
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	print("")
	print("STATES harness [%s]" % label)
	print("STATES harness — log: %s" % ProjectSettings.globalize_path(path))
	print("STATES harness — cenários=%d" % _order.size())
	print("STATES harness — ASSERT: PASS=%d FAIL=%d" % [_pass, _fail])
	if _input_flips > 0:
		print("STATES harness — nota: o modo de input foi derrubado de fora %d vez(es) durante a execução (boot do GameManager); o harness o reafirmou, então o resultado não é afetado." % _input_flips)
	if label != BASELINE_LABEL:
		_compare_with_baseline()
	if _focus_lost > 0:
		print("STATES harness — AVISO: a janela perdeu o foco %d vez(es) durante a execução." % _focus_lost)
	if not _drift.is_empty():
		print("STATES harness — AVISO: a ENTRADA foi alterada DE FORA do harness (teclado, mouse, controle ou troca de foco) em %d ponto(s):" % _drift.size())
		for d in _drift:
			print("    - %s" % d)
	# Uma linha só, que considera TUDO: interferência, asserts (CHK e NEW) e comparação com o baseline.
	if not _drift.is_empty():
		print("STATES harness — RESULTADO GERAL: INVÁLIDO — entrada externa interferiu; os números acima NÃO valem. Rode de novo sem tocar no teclado, mouse ou controle e sem trocar de janela.")
	elif _fail == 0 and _regressions == 0:
		print("STATES harness — RESULTADO GERAL: OK")
	else:
		print("STATES harness — RESULTADO GERAL: FALHOU (asserts que falharam: %d | regressões: %d)" % [_fail, _regressions])


## Compara com o baseline, separando MUDANÇA DECLARADA de REGRESSÃO.
## Um lote que muda comportamento de propósito traz um arquivo de "esperado" ao lado do harness:
##   res://_states_validation/states_<label>_esperado.txt   (transcript completo do lote, já revisado)
## Para cada cenário [REG] o resultado permitido é: o esperado do lote, se ele existir; senão o baseline.
##   igual ao baseline ................ idêntico (nada mudou)
##   diferente do baseline, igual ao esperado .... mudança DECLARADA (revisada antes)
##   qualquer outra coisa ............. REGRESSÃO: mudança que ninguém declarou
## Sem arquivo de esperado, toda mudança é regressão.
func _compare_with_baseline() -> void:
	var bpath := "user://states_%s.txt" % BASELINE_LABEL
	if not FileAccess.file_exists(bpath):
		print("STATES harness — sem baseline em %s (rode primeiro com label = baseline)." % ProjectSettings.globalize_path(bpath))
		return
	var base := _parse_groups(FileAccess.get_file_as_string(bpath))
	# O label é o nome do LOTE (ex.: a4b), não o nome do arquivo de esperado: aceita os dois.
	var batch: String = label.trim_suffix("_esperado")
	if batch != label:
		print("STATES harness — nota: label '%s' normalizado para '%s' (o label é o nome do lote; o arquivo de esperado é states_%s_esperado.txt)." % [label, batch, batch])
	var epath := "%s/states_%s_esperado.txt" % [EXPECTED_DIR, batch]
	var has_expected: bool = FileAccess.file_exists(epath)
	var expected: Dictionary = {}
	if has_expected:
		expected = _parse_groups(FileAccess.get_file_as_string(epath))
	var identical: int = 0
	var declared: Array[String] = []
	var regressions: Array[String] = []
	for sid in _order:
		if String(_groups[sid]["tag"]) != "REG":
			continue
		if not base.has(sid):
			print("STATES harness — cenário [REG] novo, sem baseline: %s (ignorado)" % sid)
			continue
		var cur: Array = _only_trace(_groups[sid]["lines"])
		var ref: Array = _only_trace(base[sid])
		var allowed: Array = _only_trace(expected[sid]) if expected.has(sid) else ref
		if cur == allowed:
			if cur == ref:
				identical += 1
			else:
				declared.append(sid)
		else:
			regressions.append(sid)
			print("REGRESSÃO (mudança NÃO declarada) em %s:" % sid)
			_print_first_diff(allowed, cur, "esperado do lote" if expected.has(sid) else "baseline")
	for sid in base:
		if sid.begins_with("REG_") and not _groups.has(sid):
			regressions.append(sid)
			print("REGRESSÃO: cenário do baseline sumiu: %s" % sid)
	print("STATES harness — esperado do lote: %s" % (ProjectSettings.globalize_path(epath) if has_expected else "NENHUM em %s (toda mudança conta como regressão)" % ProjectSettings.globalize_path(epath)))
	_regressions = regressions.size()
	if not has_expected and not regressions.is_empty():
		print("STATES harness — DICA: o arquivo de esperado do lote NÃO foi encontrado. Se as mudanças acima são as que o lote declara, copie states_%s_esperado.txt para %s e rode de novo. (O arquivo que o harness grava em AppData NÃO serve de esperado: ele só vale depois de revisado.)" % [batch, ProjectSettings.globalize_path(EXPECTED_DIR)])
	print("STATES harness — idênticos ao baseline: %d | mudaram como DECLARADO: %d | REGRESSÕES: %d" % [identical, declared.size(), regressions.size()])
	if regressions.is_empty():
		if declared.is_empty():
			print("STATES harness — COMPARAÇÃO: diff vazio (todos os cenários [REG] idênticos ao baseline).")
		else:
			print("STATES harness — COMPARAÇÃO: OK. Só mudanças declaradas: %s" % ", ".join(declared))
	else:
		print("STATES harness — COMPARAÇÃO: %d REGRESSÃO(ÕES) — mudança(s) que o lote não declarou." % regressions.size())


## `ref_label` diz de onde vem o lado esquerdo: "esperado do lote" (arquivo de esperado) ou "baseline".
func _print_first_diff(ref: Array, cur: Array, ref_label: String = "baseline") -> void:
	var n: int = maxi(ref.size(), cur.size())
	for i in n:
		var a: String = ref[i] if i < ref.size() else "<fim>"
		var b: String = cur[i] if i < cur.size() else "<fim>"
		if a != b:
			print("  linha %d" % (i + 1))
			print("  %s: %s" % [ref_label.rpad(17), a])
			print("  %s: %s" % ["atual".rpad(17), b])
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
