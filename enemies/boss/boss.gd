# enemies/boss/Boss.gd
# Patch do Batch 6 — adiciona BTRunner, is_acting e set_visual_state().
# StateMachine é MANTIDA para Intro e Death.
# BTRunner assume o controle após o Intro.

class_name Boss
extends Actor

@export var data: BossData

@onready var state_machine:   StateMachine   = $StateMachine
@onready var visual_library:  VisualLibrary  = $VisualLibrary
@onready var fx_component:    FXComponent    = $FXComponent
@onready var hp_system:       HPSystem       = $HPSystem
@onready var damage_handler:  DamageHandler  = $DamageHandler
@onready var heal_handler:    HealHandler    = $HealHandler
## BTRunner — filho direto do Boss em Boss.tscn.
## Configurar: arraste o BT_<Boss>.tres no campo `tree` do BTRunner.
@onready var bt_runner:       BTRunner       = $BTRunner

var current_phase:  int  = 0
var _phase_cooldown: float = 0.0
var arena_bounds:   Rect2 = Rect2(0, 0, 320, 224)
var is_defeated:    bool  = false

## Distância horizontal (px) abaixo da qual o boss considera o alvo "alinhado" e mantém
## o facing atual — evita ficar virando de um lado pro outro quando o X é quase igual.
const FACE_DEAD_ZONE := 4.0

## Fase cujo threshold de HP já foi cruzado, mas que só entra em vigor quando o combo
## atual terminar (ver _check_phase_transition e select_pattern). -1 = nenhuma.
var _pending_phase: int = -1
## Grupo dos nós de chão PERIGOSOS (ex: a TileMapLayer LavaFloor). Ficar sobre eles exige
## recuperação (ver is_landing_safe / prepare_recovery).
const UNSAFE_GROUND_GROUP := &"unsafe_ground"
## Posição de onde o ataque atual começou, em chão seguro — só para a saída segura.
var _recovery_anchor: Vector2 = Vector2.ZERO
var _has_recovery_anchor: bool = false
## Memória da seleção de combos (reiniciada a cada fase e no retry).
var _sequence_index: int = 0
var _last_pattern: AttackPattern = null

## Flag para sistemas externos (DamageHandler, etc.).
## A BT NÃO usa esta flag para controlar o tick — ela controla internamente via RUNNING.
var is_acting: bool = false

## Onde o boss nasceu — destino do reset_for_retry(). Guardado uma vez, no _start().
var _initial_position: Vector2 = Vector2.ZERO
var _has_initial_position: bool = false
## Objetos spawnados na luta (projéteis, colunas...). Rastreados para limpar no retry.
var _spawned_objects: Array[Node2D] = []

signal boss_defeated(has_final_dialogue: bool)
signal phase_changed(new_phase: int)


# ─────────────────────────────────────────────────────────────
# GODOT
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("boss")
	process_mode = Node.PROCESS_MODE_PAUSABLE
 
	if not data:
		push_error("Boss '%s': BossData não configurado." % name)
		return
 
	arena_bounds = data.arena_bounds.abs()
	if (arena_bounds.size.x > 0.0) != (arena_bounds.size.y > 0.0):
		push_warning("Boss '%s': arena_bounds com extensão 0 em um eixo (%s) — esse eixo NÃO será limitado. Configure Size X/Y." % [name, str(arena_bounds)])
 
	if data.sprite_frames and sprite:
		sprite.sprite_frames = data.sprite_frames
 
	# FIX 1: sem isso, GameManager.current_boss nunca é setado.
	GameManager.register_boss(self)
 
	if damage_handler and data.resistance_table:
		damage_handler.resistance_table = data.resistance_table
 
	if hp_system:
		hp_system.depleted.connect(_on_defeated)
	else:
		push_error("Boss '%s': HPSystem não encontrado." % name)
 
	if bt_runner:
		bt_runner.enabled = false
 
	# FIX 2: sem isso, VisualLibrary._owner fica null e set_visual_state()
	# não tem como saber qual Actor/Sprite usar.
	visual_library.initialize(self)
 
	# FIX 3: sem isso, state_machine._host fica null e states.clear()
	# nunca popula — nenhum state (Intro, Death) consegue rodar.
	state_machine.initialize(self)
 
	call_deferred("_start")





func _start() -> void:
	if not _has_initial_position:
		_initial_position = global_position
		_has_initial_position = true
	# Boss aguarda em idle. CutsceneSequencer controla a animação de
	# entrada via StepAnimation (grupo "boss_sprite" no editor).
	# BossFlowManager liga o BTRunner quando BOSS_FIGHT começar.
	if data:
		set_facing(data.starts_facing_right)
	set_visual_state(&"magma_dragoon_idle")



## Devolve o boss ao estado inicial da luta (o jogador morreu na arena).
## Chamado pelo BossFlowManager.abort_fight(). A luta recomeça pelo fluxo normal:
## porta → intro → apresentação → BOSS_FIGHT (que religa o BTRunner).
func reset_for_retry() -> void:
	# Interrompe a árvore de comportamento (ação em andamento incluída).
	if bt_runner:
		bt_runner.stop()
	is_acting = false

	# Limpa o que a luta deixou na fase.
	_clear_spawned_objects()
	if fx_component:
		fx_component.stop_all()

	# Estado lógico: fase 0, HP cheio, sem i-frames.
	current_phase = 0
	_pending_phase = -1
	_has_recovery_anchor = false
	_sequence_index = 0
	_last_pattern = null
	_phase_cooldown = 0.0
	invulnerability = 0.0
	toggleable_invulnerabilities.clear()  # travas de AnimPhase.invulnerable da luta anterior
	velocity = Vector2.ZERO
	if hp_system:
		hp_system.apply_full_heal()

	# Posição, direção e visual iniciais (o mesmo que o boss faz ao nascer).
	global_position = _initial_position
	_start()


func _clear_spawned_objects() -> void:
	for obj in _spawned_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	_spawned_objects.clear()


func _process_state(delta: float) -> void:
	if state_machine:
		state_machine.process_state(delta)
	_enforce_arena(delta)
	if _phase_cooldown > 0.0:
		_phase_cooldown -= delta


# ─────────────────────────────────────────────────────────────
# VISUAL — chamado pela BossAction
# ─────────────────────────────────────────────────────────────

## Aplica uma animação via VisualLibrary.
## BossAction chama este método — nunca acessa o sprite diretamente.
## VisualLibrary já tem o SpriteFrames carregado (via BossData.sprite_frames).
##
## TODO: quando PathResolver existir, mover a resolução de path para lá.
func set_visual_state(anim_name: StringName) -> void:
	if visual_library:
		# push_warning("TODO: PathResolver") — remover quando PathResolver existir.
		visual_library.play_state(String(anim_name))




# ─────────────────────────────────────────────────────────────
# HP
# ─────────────────────────────────────────────────────────────

func take_damage(value: float, inflicter = null) -> void:
	if is_defeated or _is_invulnerable():
		return

	var tag: String = ""
	if inflicter and inflicter.has_method("get_damage_tag"):
		tag = inflicter.get_damage_tag()
	if _is_immune_to(tag):
		return

	var type_id: StringName = DamageType.CONTACT
	if inflicter and inflicter.has_method("get_damage_type_id"):
		type_id = inflicter.get_damage_type_id()

	if damage_handler:
		damage_handler.receive(value, type_id, inflicter)
	else:
		push_warning("Boss '%s': DamageHandler não encontrado." % name)
		return

	if hit_effect:
		ParticleFX.spawn_at(hit_effect, global_position)

	if not is_defeated:
		_check_phase_transition()


func heal(value: float) -> void:
	if heal_handler:
		heal_handler.heal(ceili(value))


func _is_immune_to(tag: String) -> bool:
	if tag.is_empty() or not data:
		return false
	if current_phase >= data.phases.size():
		return false
	return tag in data.phases[current_phase].immune_to


# ─────────────────────────────────────────────────────────────
# PHASE SYSTEM
# ─────────────────────────────────────────────────────────────

## O HP cruzou o threshold → só MARCA a fase como pendente. Ela entra em vigor no próximo
## select_pattern(), isto é, quando o combo em andamento terminar — o boss não interrompe
## a própria sequência de ataques no meio.
func _check_phase_transition() -> void:
	if not data or _phase_cooldown > 0.0 or _pending_phase >= 0:
		return
	var ratio := hp_system.hp_ratio if hp_system else 0.0
	for i in data.phases.size():
		if i <= current_phase:
			continue
		var phase: BossPhaseData = data.phases[i]
		if ratio <= phase.hp_threshold:
			_pending_phase = i
			return


func _activate_phase(index: int) -> void:
	if not data or index >= data.phases.size():
		return
	current_phase   = index
	_pending_phase  = -1
	_sequence_index = 0
	_last_pattern   = null
	_phase_cooldown = 1.0
	var phase: BossPhaseData = data.phases[index]
	if not phase.phase_music.is_empty():
		SoundManager.stop_music()
		SoundManager.play_music(phase.phase_music)
	if not phase.entry_sfx.is_empty():
		SoundManager.play_sfx(phase.entry_sfx)
	phase_changed.emit(index)
	# NOTA: state_machine.change_state(phase.entry_state) foi removido —
	# StateMachine fica restrita a Intro/Death. Mudança de comportamento
	# por fase agora é responsabilidade da Behavior Tree, que já lê
	# current_phase via BTBlackboard.CURRENT_PHASE (ver BTRunner).
	# entry_state fica sem uso no BossPhaseData por enquanto.


func get_current_phase_data() -> BossPhaseData:
	if not data or current_phase >= data.phases.size():
		return null
	return data.phases[current_phase]


# ─────────────────────────────────────────────────────────────
# DEFEAT
# ─────────────────────────────────────────────────────────────

func _on_defeated() -> void:
	is_defeated = true
	# Para a BT imediatamente — limpa is_acting e qualquer ação em curso.
	if bt_runner:
		bt_runner.stop()
	# Objetos da luta somem; o boss em si fica vivo até a cutscene de derrota.
	_clear_spawned_objects()
	boss_defeated.emit(data.has_final_dialogue if data else false)


## Destruição do boss: spawna o death_effect sobre o corpo. Para explosões espalhadas,
## configure o SpawnedParticleDef com burst_count + spawn_interval + position_variance.
## NÃO esconde o corpo — a cutscene decide quando (StepCall "hide" no grupo "boss").
## Chamado pela defeat_cutscene (StepCall) ou, sem ela, pelo BossFlowManager.
func play_destruction() -> void:
	if death_effect:
		ParticleFX.spawn_at(death_effect, global_position, Vector2.ZERO, self)


# ─────────────────────────────────────────────────────────────
# ARENA + FACING + SPAWN + DEBUG (inalterados do Batch 3/5A)
# ─────────────────────────────────────────────────────────────

func _enforce_arena(_delta: float) -> void:
	# Range [position, position + size] por eixo. Eixo com extensão 0 =
	# sem limite (antes ele PRENDIA o boss numa coordenada fixa).
	var b := arena_bounds
	if b.size.x > 0.0:
		global_position.x = clampf(global_position.x, b.position.x, b.end.x)
	if b.size.y > 0.0:
		global_position.y = clampf(global_position.y, b.position.y, b.end.y)
	if arena_bounds.size == Vector2.ZERO:
		return
	global_position.x = clampf(
		global_position.x,
		arena_bounds.position.x,
		arena_bounds.position.x + arena_bounds.size.x
	)
	global_position.y = clampf(
		global_position.y,
		arena_bounds.position.y,
		arena_bounds.position.y + arena_bounds.size.y
	)


func set_facing(right: bool) -> void:
	if facing_right == right:
		return
	facing_right  = right
	# flip_h só deve inverter quando a direção desejada diverge da
	# direção nativa da arte — não sempre que right == false, como
	# assumia a fórmula antiga. Sem isso, bosses com arte desenhada
	# olhando pra esquerda (ex: Magma Dragoon) ficam invertidos.
	var native_right := data.native_facing_right if data else true
	sprite.flip_h = (right != native_right)


## +1 ou -1: o quanto o visual está espelhado em relação à arte NATIVA (BossData.native_facing_right).
## Mesma regra do offset_flip de _spawn_object(). Lido pelo ParticleFX para espelhar markers
## (SpawnedParticleDef.mirror_marker_with_facing).
func get_facing_flip() -> int:
	var native_right := data.native_facing_right if data else true
	return -1 if facing_right != native_right else 1


# ─────────────────────────────────────────────────────────────
# POUSO E RECUPERAÇÃO — chamados pela BossAction (check_landing / recovery_phases)
# ─────────────────────────────────────────────────────────────

## true se o boss está no chão E esse chão não é do grupo UNSAFE_GROUND_GROUP. Decide pelo
## collider do chão (física real), nunca pela altura: o fosso e a plataforma da arena
## compartilham a mesma collision layer, e só o grupo as diferencia.
func is_landing_safe() -> bool:
	if not is_on_floor():
		return false
	return _is_safe_ground(get_floor_collider())


func _is_safe_ground(collider: Object) -> bool:
	return collider != null and not (collider is Node and (collider as Node).is_in_group(UNSAFE_GROUND_GROUP))


## Guarda a posição atual como "último ponto seguro" (se ela for mesmo segura).
func mark_recovery_anchor() -> void:
	if is_landing_safe():
		_recovery_anchor = global_position
		_has_recovery_anchor = true


## Escolhe o lado do pulo de recuperação e vira o boss para ele. Testa primeiro o lado do
## jogador (ele está na arena) e depois o oposto; um lado só vale se a PREDIÇÃO do pulo (mesma
## física do jogo, ver Actor.predict_physical_move) POUSA em chão seguro. Uma parede no meio
## do caminho não é checada à parte: se ela impede a saída, o corpo desliza de volta e pousa
## no fosso — e aí o collider do pouso já reprova o lado. false = nenhum lado serve.
func prepare_recovery(move_def: PhysicalMoveDef) -> bool:
	var native_right := data.native_facing_right if data else true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var prefer_right := (player.global_position.x >= global_position.x) if player else facing_right
	for right in [prefer_right, not prefer_right]:
		var flip := 1 if right == native_right else -1
		var r := predict_physical_move(move_def, flip)
		if r.landed and _is_safe_ground(r.floor_collider):
			set_facing(right)
			return true
	return false


## Saída segura quando a recuperação não é possível: volta ao último ponto seguro, em vez de
## deixar o boss atacando dentro do fosso. Sem ponto guardado, só avisa.
func recovery_failsafe() -> void:
	if not _has_recovery_anchor:
		push_warning("Boss: recuperação impossível e nenhum ponto seguro guardado.")
		return
	stop_physical_move()
	velocity = Vector2.ZERO
	global_position = _recovery_anchor


## true se uma fase já foi "ganha" por HP mas ainda não entrou em vigor.
## Lido pelo BTAction para não repetir (loop) o combo atual.
func has_pending_phase() -> bool:
	return _pending_phase >= 0


## Vira para o alvo (comparando só o X). Alinhado (dentro da zona morta) mantém o facing.
## Quem decide QUANDO chamar é o BTAction, na entrada de cada combo.
func face_toward(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var dx := target.global_position.x - global_position.x
	if absf(dx) <= FACE_DEAD_ZONE:
		return
	set_facing(dx > 0.0)


## Escolhe o próximo combo. Chamado pelo BTAction ao iniciar cada combo.
## ATENÇÃO: efeito colateral intencional — se há fase pendente, é AQUI que ela entra em
## vigor (música, SFX, phase_changed), porque este é o ponto seguro: o combo anterior
## acabou. Nesse caso devolve o entry_pattern da nova fase (uma vez só).
func select_pattern(player_ref: Node = null) -> AttackPattern:
	if _pending_phase >= 0:
		var entering := _pending_phase
		_pending_phase = -1
		_activate_phase(entering)
		var entered := get_current_phase_data()
		if entered and entered.entry_pattern and not entered.entry_pattern.attacks.is_empty():
			return entered.entry_pattern

	var phase := get_current_phase_data()
	if not phase:
		return null

	var chosen: AttackPattern = null
	match phase.selection_mode:
		BossPhaseData.SelectionMode.SEQUENTIAL:
			chosen = _pick_sequential(phase, player_ref)
		BossPhaseData.SelectionMode.WEIGHTED_NO_REPEAT:
			chosen = _pick_weighted(_eligible_patterns(phase, player_ref), _last_pattern)
		_:
			chosen = _pick_weighted(_eligible_patterns(phase, player_ref))
	_last_pattern = chosen
	return chosen


func _eligible_patterns(phase: BossPhaseData, player_ref: Node) -> Array[AttackPattern]:
	var eligible: Array[AttackPattern] = []
	for pattern in phase.patterns:
		if pattern and _pattern_condition_met(pattern, player_ref):
			eligible.append(pattern)
	return eligible


## Sorteio ponderado por weight. `avoid` é excluído, a menos que seja a única opção.
func _pick_weighted(eligible: Array[AttackPattern], avoid: AttackPattern = null) -> AttackPattern:
	if eligible.is_empty():
		return null
	var pool: Array[AttackPattern] = []
	for p in eligible:
		if p != avoid or eligible.size() == 1:
			pool.append(p)
	if pool.is_empty():
		pool = eligible
	var total_weight := 0.0
	for p in pool:
		total_weight += p.weight
	var roll := randf() * total_weight
	var accumulated := 0.0
	for p in pool:
		accumulated += p.weight
		if roll <= accumulated:
			return p
	return pool[-1]


## Próximo da lista (a partir de onde parou) que esteja elegível; ao fim volta ao primeiro.
func _pick_sequential(phase: BossPhaseData, player_ref: Node) -> AttackPattern:
	var count := phase.patterns.size()
	for step in count:
		var idx := (_sequence_index + step) % count
		var pattern := phase.patterns[idx]
		if pattern and _pattern_condition_met(pattern, player_ref):
			_sequence_index = (idx + 1) % count
			return pattern
	return null


func _pattern_condition_met(pattern: AttackPattern, player_ref: Node) -> bool:
	if pattern.condition.is_empty():
		return true
	if not player_ref:
		return false
	var diff: Vector2 = player_ref.global_position - global_position
	match pattern.condition:
		"player_near_wall":
			var margin := 32.0
			return (
				player_ref.global_position.x < arena_bounds.position.x + margin or
				player_ref.global_position.x > arena_bounds.position.x + arena_bounds.size.x - margin
			)
		"player_above":  return diff.y < -32.0
		"player_below":  return diff.y > 32.0
		"player_close":  return diff.length() < 80.0
		"player_far":    return diff.length() > 120.0
	return true


func execute_spawn(attack: BossAttack) -> void:
	for obj in attack.spawn_objects:
		_spawn_object(obj)


## Ponto de entrada público para FrameEvent.Type.SPAWN_OBJECT (via BossAction).
## Reaproveita a mesma lógica de spawn usada pelo AttackPattern antigo.
## Retorna o Node2D instanciado (ou null se falhou) — usado por BossAction
## pra saber qual é a "cabeça" de uma cadeia (FXChainDef) disparada logo
## em seguida no mesmo FrameEvent.SPAWN_FX.
func spawn_object(obj: SpawnableObject) -> Node2D:
	return _spawn_object(obj)


func _spawn_object(obj: SpawnableObject) -> Node2D:
	if not ResourceLoader.exists(obj.scene_path):
		push_warning("Boss: cena não encontrada: " + obj.scene_path)
		return null
	var player_ref := get_tree().get_first_node_in_group("player")
	var spawn_pos: Vector2

	# Direção de MUNDO (+1 direita / -1 esquerda) — pro movimento físico
	# do projétil. Segue facing_right puro, sempre — independente de
	# como a arte nativa foi desenhada.
	var world_dir := 1 if facing_right else -1

	# Flip do OFFSET — DIFERENTE da direção de mundo. offset.x é medido
	# olhando a arte no editor, ou seja, na orientação NATIVA dela. Só
	# inverte quando o facing atual diverge da nativa (mesma lógica que
	# set_facing() já usa pra decidir sprite.flip_h).
	var native_right := data.native_facing_right if data else true
	var offset_flip := -1 if (facing_right != native_right) else 1

	if obj.spawn_at_player and player_ref:
		spawn_pos = player_ref.global_position + obj.offset
	else:
		var offset_x := obj.offset.x * offset_flip if obj.flip_with_facing else obj.offset.x
		print("[DEBUG] facing_right: ", facing_right, " | native_right: ", native_right,
			" | offset_flip: ", offset_flip, " | flip_with_facing: ", obj.flip_with_facing,
			" | offset.x bruto: ", obj.offset.x, " | offset_x final: ", offset_x)
		spawn_pos = global_position + Vector2(offset_x, obj.offset.y)
	var instance: Node2D = load(obj.scene_path).instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = spawn_pos
	# Projéteis direcionais (ex: Hadouken) expõem launch(direction) —
	# sempre a direção de MUNDO, nunca o offset_flip.
	if instance.has_method("launch"):
		instance.launch(world_dir)
	bind_spawned_object(instance, obj)
	if obj.lifetime > 0.0:
		get_tree().create_timer(obj.lifetime).timeout.connect(instance.queue_free)
	if obj.spawn_fx:
		ParticleFX.spawn_at(obj.spawn_fx, spawn_pos)
	return instance


## Liga um objeto recém-instanciado ao sistema de hit (se `obj` for passado e o objeto tiver
## um HitComponent) e ao reset_for_retry(), que o limpa. Usado por _spawn_object() e por quem
## spawna objetos por conta própria (ex: BarrageController). O tipo de dano usa a mesma
## string da damage_tag.
func bind_spawned_object(instance: Node2D, obj: SpawnableObject = null) -> void:
	if obj:
		var hit_component := instance.get_node_or_null("HitComponent") as HitComponent
		if hit_component:
			hit_component.attacker       = self
			hit_component.damage         = obj.damage
			hit_component.damage_tag     = obj.damage_tag
			hit_component.damage_type_id = StringName(obj.damage_tag)
	# Rastreia para o reset_for_retry() poder limpar (descarta os já liberados).
	_spawned_objects = _spawned_objects.filter(func(o): return is_instance_valid(o))
	_spawned_objects.append(instance)


func debug_force_phase(index: int) -> void:
	_activate_phase(index)


## Debug apenas — força a direção do boss pra testar o lado espelhado
## (ex: confirmar que o Hadouken sai certo pros dois lados antes de
## reverter pra starts_facing_right real do Magma Dragoon).
func debug_force_facing(right: bool) -> void:
	set_facing(right)


func debug_set_hp(value: float) -> void:
	if not hp_system:
		return
	hp_system.debug_force_units(ceili(value))
	_check_phase_transition()
