# Boss.gd
# Herda de Actor diretamente — linha independente de Enemy e Character.
# Infraestrutura pura: StateMachine, PhaseSystem, Arena, VisualLibrary, FX.
# Zero behavior — cada boss filho implementa seus próprios states.
class_name Boss
extends Actor

# ── Data ─────────────────────────────────────────────────────
@export var data: BossData

# ── Nós internos ─────────────────────────────────────────────
@onready var state_machine:   StateMachine   = $StateMachine
@onready var visual_library:  VisualLibrary  = $VisualLibrary
@onready var fx_component:    FXComponent    = $FXComponent

# ── HP ───────────────────────────────────────────────────────
var hp: float = 0.0
var hp_max: float = 0.0

# ── Fase atual ───────────────────────────────────────────────
var current_phase: int = 0
var _phase_cooldown: float = 0.0  # evita troca de fase em loop

# ── Arena ─────────────────────────────────────────────────────
# Bounds em global coords — setado por quem colocar o boss na cena.
var arena_bounds: Rect2 = Rect2(0, 0, 320, 224)

# ── Estado interno ───────────────────────────────────────────
var is_defeated: bool = false

# ── Sinais ───────────────────────────────────────────────────
signal boss_defeated(has_final_dialogue: bool)
signal phase_changed(new_phase: int)


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	add_to_group("boss")
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if not data:
		push_error("Boss '%s': BossData não configurado." % name)
		return

	hp     = data.hp_total
	hp_max = data.hp_total
	arena_bounds = data.arena_bounds

	if data.sprite_frames and sprite:
		sprite.sprite_frames = data.sprite_frames

#	visual_library.initialize(self)
#	state_machine.initialize(self)

	call_deferred("_start")


func _start() -> void:
	state_machine.change_state("Intro")


# ============================================================
# PHYSICS — hook do Actor
# ============================================================

func _process_state(delta: float) -> void:
	if state_machine:
		state_machine.process_state(delta)
	_enforce_arena(delta)
	if _phase_cooldown > 0.0:
		_phase_cooldown -= delta


# ============================================================
# HP
# ============================================================

func take_damage(value: float, inflicter = null) -> void:
	if is_defeated or _is_invulnerable():
		return

	# Verifica imunidade da fase atual
	var tag: String = ""
	if inflicter and inflicter.has_method("get_damage_tag"):
		tag = inflicter.get_damage_tag()
	if _is_immune_to(tag):
		return

	hp = maxf(0.0, hp - value)
	hp_changed.emit(hp, hp_max)
	damaged.emit(value, inflicter)

	if hit_effect:
		ParticleFX.spawn_at(hit_effect, global_position)

	_check_phase_transition()

	if hp <= 0.0 and not is_defeated:
		_on_defeated()


func heal(value: float) -> void:
	hp = minf(hp_max, hp + value)
	hp_changed.emit(hp, hp_max)


# ── Imunidade por fase ───────────────────────────────────────

func _is_immune_to(tag: String) -> bool:
	if tag.is_empty() or not data:
		return false
	if current_phase >= data.phases.size():
		return false
	return tag in data.phases[current_phase].immune_to


# ============================================================
# PHASE SYSTEM
# ============================================================

func _check_phase_transition() -> void:
	if not data or _phase_cooldown > 0.0:
		return

	var hp_pct := hp / hp_max

	for i in data.phases.size():
		if i <= current_phase:
			continue
		var phase: BossPhaseData = data.phases[i]
		if hp_pct <= phase.hp_threshold:
			_activate_phase(i)
			return


func _activate_phase(index: int) -> void:
	if not data or index >= data.phases.size():
		return

	current_phase  = index
	_phase_cooldown = 1.0   # previne transição dupla no mesmo frame

	var phase: BossPhaseData = data.phases[index]

	# Música da fase
	if not phase.phase_music.is_empty():
		SoundManager.stop_music()
		SoundManager.play_music(phase.phase_music)

	# SFX de entrada
	if not phase.entry_sfx.is_empty():
		SoundManager.play_sfx(phase.entry_sfx)

	phase_changed.emit(index)
	print("🔥 Boss fase %d ativada" % index)

	# Muda para o estado de entrada da fase se definido
	if not phase.entry_state.is_empty():
		state_machine.change_state(phase.entry_state)


func get_current_phase_data() -> BossPhaseData:
	if not data or current_phase >= data.phases.size():
		return null
	return data.phases[current_phase]


# ============================================================
# DEFEAT
# ============================================================

func _on_defeated() -> void:
	is_defeated = true

	if death_effect:
		ParticleFX.spawn_at(death_effect, global_position)

	state_machine.change_state("Death")
	boss_defeated.emit(data.has_final_dialogue if data else false)


# ============================================================
# ARENA — mantém o boss dentro dos limites
# ============================================================

func _enforce_arena(_delta: float) -> void:
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


# ============================================================
# ATTACK PATTERN — helpers para os states filhos
# ============================================================

## Seleciona um pattern elegível da fase atual por rolagem ponderada.
## Retorna null se nenhum for elegível.
func select_pattern(player_ref: Node = null) -> AttackPattern:
	var phase := get_current_phase_data()
	if not phase:
		return null

	var eligible: Array[AttackPattern] = []
	for pattern in phase.patterns:
		if _pattern_condition_met(pattern, player_ref):
			eligible.append(pattern)

	if eligible.is_empty():
		return null

	# Rolagem ponderada
	var total_weight := 0.0
	for p in eligible:
		total_weight += p.weight

	var roll := randf() * total_weight
	var accumulated := 0.0
	for p in eligible:
		accumulated += p.weight
		if roll <= accumulated:
			return p

	return eligible[-1]


func _pattern_condition_met(pattern: AttackPattern, player_ref: Node) -> bool:
	if pattern.condition.is_empty():
		return true
	if not player_ref:
		return false

	var diff: Vector2 = player_ref.global_position - global_position

	match pattern.condition:
		"player_near_wall":
			# Considera perto de parede se player está no limite horizontal da arena
			var margin := 32.0
			return (
				player_ref.global_position.x < arena_bounds.position.x + margin or
				player_ref.global_position.x > arena_bounds.position.x + arena_bounds.size.x - margin
			)
		"player_above":
			return diff.y < -32.0
		"player_below":
			return diff.y > 32.0
		"player_close":
			return diff.length() < 80.0
		"player_far":
			return diff.length() > 120.0

	return true


## Spawna todos os objetos de um BossAttack.
func execute_spawn(attack: BossAttack) -> void:
	for obj in attack.spawn_objects:
		_spawn_object(obj)


func _spawn_object(obj: SpawnableObject) -> void:
	if not ResourceLoader.exists(obj.scene_path):
		push_warning("Boss: SpawnableObject cena não encontrada: " + obj.scene_path)
		return

	var player_ref := get_tree().get_first_node_in_group("player")
	var spawn_pos: Vector2

	if obj.spawn_at_player and player_ref:
		spawn_pos = player_ref.global_position + obj.offset
	else:
		var flip := -1 if not facing_right else 1
		var flipped_offset := Vector2(obj.offset.x * flip if obj.flip_with_facing else obj.offset.x, obj.offset.y)
		spawn_pos = global_position + flipped_offset

	var instance: Node2D = load(obj.scene_path).instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = spawn_pos

	if obj.lifetime > 0.0:
		get_tree().create_timer(obj.lifetime).timeout.connect(instance.queue_free)

	if obj.spawn_fx:
		ParticleFX.spawn_at(obj.spawn_fx, spawn_pos)


# ============================================================
# FACING
# ============================================================

func set_facing(right: bool) -> void:
	if facing_right == right:
		return
	facing_right   = right
	sprite.flip_h  = not right


# ============================================================
# DEBUG
# ============================================================

func debug_force_phase(index: int) -> void:
	print("🔍 [Boss DEBUG] forçando fase %d" % index)
	_activate_phase(index)


func debug_set_hp(value: float) -> void:
	hp = clampf(value, 0.0, hp_max)
	hp_changed.emit(hp, hp_max)
	print("🔍 [Boss DEBUG] HP setado para %.1f / %.1f" % [hp, hp_max])
	_check_phase_transition()
