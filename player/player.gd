extends Character
class_name Player

var pressed_shoot_designedbutton: bool = false
var combo_count: int = 0
var max_combo: int = 3
var wall_slide_cooldown: float = 0.0
var wall_kick_grace: float = 0.0
var dash_jump_eligible: bool = false
var last_state_was_dash: bool = false
var came_from_jump: bool = false
var can_double_jump: bool = false
var can_air_dash: bool = true
var can_control: bool = true
var wall_slide_cancelled: bool = false
var horizontal_momentum: float = 0.0
var is_transitioning_walk: bool = false
var is_transitioning_jump: bool = false
var force_wall_facing: bool = false
var wall_slide_direction: int = 0
var switched_armor: String

# ── Morte ────────────────────────────────────────────────────
## True entre o zero_health e o respawn — impede iniciar a sequência duas vezes.
var _is_dying: bool = false
## Onde o Player nasceu na fase — destino do respawn quando não há checkpoint ativo.
var _spawn_position: Vector2 = Vector2.ZERO
## Motivo do lock de invulnerabilidade durante a sequência de morte.
const DEATH_LOCK: StringName = &"death"

@export var current_character: PlayerCharacterData
@export var current_armor: ArmorData
@export var previous_armor: ArmorData
@export var current_weapon: WeaponData

var forced_move_direction: Vector2 = Vector2.ZERO
var forced_move_speed: float = 0.0


@onready var state_machine: StateMachine = $StateMachine
@onready var wall_ray: RayCast2D = $WallRay
## Único CollisionShape2D do corpo; muda de tamanho por perfil (apply_collision_stance).
@onready var body_collision: CollisionShape2D = $BodyCollision
## Perfil de colisão aplicado (PlayerCharacterData.Stance). -1 = nenhum ainda.
var _collision_stance: int = -1

@onready var layer_head: AnimatedSprite2D = $ArmorLayerHead
@onready var layer_body: AnimatedSprite2D = $ArmorLayerBody
@onready var layer_arms: AnimatedSprite2D = $ArmorLayerArms
@onready var layer_legs: AnimatedSprite2D = $ArmorLayerLegs

@onready var arm_base_layer: Node = $ArmBaseLayer
@onready var buster_layer: Node = $BusterLayer
@onready var charge_system: Node = $ChargeSystem

@onready var spawn_right: Marker2D = $SpawnRight_idle
@onready var spawn_left: Marker2D = $SpawnLeft_idle
@onready var spawn_right_walk: Marker2D = $SpawnRight_walk
@onready var spawn_left_walk: Marker2D = $SpawnLeft_walk

@onready var visual_library: VisualLibrary = $VisualLibrary
@onready var fx_component: FXComponent = $FXComponent

var _layer_nodes: Dictionary = {}
var char_path: String = ""
var armor_path: String = ""
var bsarmrpath: String = "res://player/data/armors/"



# ============================================================
# READY
# ============================================================

func _ready() -> void:
	sprite.position = Vector2.ZERO
	process_priority = 0
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	_spawn_position = global_position

	_init_layer_nodes()

	# Bridge de compatibilidade: GameManager.current_player = "X" / "Zero"
	# é setado pelo PLAYER_SELECT antes de entrar na stage.
	# CharacterManagement.set_initial() registra quem é o ativo e sincroniza.
	CharacterManagement.set_initial(StringName(GameManager.current_player))
	current_character = CharacterManagement.get_active_data()

	if not current_character:
		push_error("[Player] CharacterManagement sem personagem ativo.")
		return

	current_armor = current_character.get_default_armor()

	# Conecta APÓS set_initial para não reagir desnecessariamente no _ready.
	CharacterManagement.character_switched.connect(_on_character_switched)
	zero_health.connect(_on_zero_health)

	_setup_character()

	call_deferred("play_stage_intro")


# ============================================================
# HOOK DE ESTADO — chamado pelo Actor._physics_process
# ============================================================

func _process_state(delta: float) -> void:
	if state_machine:
		state_machine.process_state(delta)

	ArmorManager.sync_frame(self)
	wall_slide_cooldown = max(0.0, wall_slide_cooldown - delta)
	wall_kick_grace     = max(0.0, wall_kick_grace - delta)


# ── HP — override de Actor.take_damage ────────────────────────────────────────
 
## Roteia dano pelo DamageHandler → HPSystem.
## NÃO chama super — DamageHandler já emite damaged e HPSystem sincroniza Actor.
##
## damage_type_id é extraído do inflicter via get_damage_type_id().
## Se o inflicter não implementar o método: fallback para DamageType.CONTACT.
## Isso garante que colisões sem tipo definido ainda causem dano normalmente.
func take_damage(value: float, inflicter = null) -> void:
	if _is_invulnerable():
		return
 
	# Extrai o tipo de dano do inflicter.
	# Qualquer projétil/hazard que implemente get_damage_type_id() → StringName
	# tem seu tipo reconhecido automaticamente.
	# Sem esse método: CONTACT (dano físico genérico, sem resistência especial).
	var type_id: StringName = DamageType.CONTACT
	if inflicter != null and inflicter.has_method("get_damage_type_id"):
		type_id = inflicter.get_damage_type_id()
 
	var dh := get_node_or_null("DamageHandler") as DamageHandler
	if dh:
		dh.receive(value, type_id, inflicter)
		if hit_effect:
			ParticleFX.spawn_at(hit_effect, global_position)
	else:
		push_warning("[Player] DamageHandler não encontrado — usando Actor.take_damage().")
		super.take_damage(value, inflicter)



# ============================================================
# MORTE E RESPAWN
# ============================================================

## Chamado quando o HP chega a zero (Actor.zero_health).
## Congela o Player, trava novos hits e toca a death_cutscene da ficha do
## personagem atual. A cutscene chama respawn() no momento certo (StepCall).
func _on_zero_health() -> void:
	if _is_dying:
		return
	_is_dying = true

	can_control = false
	velocity    = Vector2.ZERO
	set_physics_process(false)

	var hp := get_node_or_null("HPSystem") as HPSystem
	if hp:
		hp.lock(DEATH_LOCK)

	# Cancela braço/buster/efeitos de carga em andamento, para a pose de morte
	# aparecer limpa (mesma limpeza da troca de personagem).
	arm_base_layer.reset()
	buster_layer._cancel()
	fx_component.stop_all()

	_set_camera_target(null)

	var cutscene: CutsceneData = current_character.death_cutscene if current_character else null
	if cutscene:
		CutsceneSequencer.play(cutscene)
	else:
		push_warning("[Player] Sem death_cutscene na ficha do personagem — respawn direto.")
		respawn()


## Reaparece no checkpoint ativo (ou no ponto inicial da fase) com HP cheio.
## Chamado pelo StepCall da death_cutscene, ou direto se não houver cutscene.
## Ordem importa: o HP volta ANTES de zerar emitted_zero_health, senão o Actor
## veria HP zero e emitiria zero_health de novo.
func respawn() -> void:
	# Ondas de FX da morte (ex: orbes repetidas) param aqui, no preto do fade.
	ParticleFX.stop_all_continuous()

	# Avisa o GameManager da falha: ele decide o que resetar (música, luta de boss...).
	GameManager.on_player_failed()

	var hp := get_node_or_null("HPSystem") as HPSystem
	if hp:
		hp.apply_full_heal()
	emitted_zero_health = false
	if hp:
		hp.unlock(DEATH_LOCK)

	velocity = Vector2.ZERO
	set_physics_process(true)
	_is_dying = false

	var checkpoint := GameManager.active_checkpoint
	if is_instance_valid(checkpoint):
		checkpoint.respawn_player(self)  # move, mostra e entra no state Intro
	else:
		global_position = _spawn_position
		visible = true
		state_machine.change_state("Intro")

	_set_camera_target(self)


## Toca uma VisualSequence do personagem atual pelo nome (ex: "Death").
## Tem a mesma assinatura (play(String)) que o CutsceneSequencer chama em qualquer
## nó do grupo, então o StepAnimation funciona com o Player sem mudar o sequencer.
## O arquivo de sprites vem do personagem ativo (VisualLibrary.load_frames).
func play(sequence_name: String) -> void:
	state_machine.visual_sequence_player.play(self, sequence_name)


## Entra no state Victory: o Player fica parado e nenhum outro state sobrescreve a
## pose. Chamado pelo BossFlowManager antes da victory_cutscene.
func start_victory() -> void:
	state_machine.change_state("Victory")


## Define quem a câmera principal segue. null = a câmera para onde está.
func _set_camera_target(new_target: Node2D) -> void:
	var cam := get_tree().get_first_node_in_group("GmCamera") as StablePixelCamera
	if cam:
		cam.target = new_target


# ============================================================
# SETUP
# ============================================================

func play_stage_intro() -> void:
	state_machine.change_state("Intro")


## Aplica o perfil de colisão do corpo (em pé, dash, agachado) com as medidas da ficha do
## personagem. Os pés ficam fixos (feet_offset_y); só o topo sobe/desce, e o alcance do
## WallRay acompanha a meia-largura. Chamado pelo StateMachine.change_state().
## set_deferred: um hit pode trocar de state dentro de um callback de física, onde o Godot
## proíbe alterar shapes.
## LIMITAÇÃO conhecida: não verifica teto ao crescer (ex: sair do dash sob teto baixo).
## Tratar junto com o crouch.
func apply_collision_stance(stance: int) -> void:
	if not current_character or not body_collision or stance == _collision_stance:
		return
	var shape := body_collision.shape as RectangleShape2D
	if not shape:
		push_warning("Player: BodyCollision precisa de um RectangleShape2D.")
		return
	_collision_stance = stance

	var size := current_character.get_collision_size(stance)
	shape.set_deferred("size", size)
	body_collision.set_deferred("position", Vector2(0.0, current_character.feet_offset_y - size.y * 0.5))

	var side := -1.0 if wall_ray.target_position.x < 0.0 else 1.0
	wall_ray.target_position.x = side * (size.x * 0.5 + current_character.wall_reach)


## Inicializa todos os sistemas para o current_character atual.
## Compartilhado entre _ready() e _on_character_switched().
func _setup_character() -> void:
	ArmorManager.on_player_ready(self)

	# Efeito de morte vem da ficha: o Actor o spawna sozinho no zero_health.
	death_effect = current_character.death_effect

	# Capability flags substituem if ["X","Zero"] hardcoded.
	# Adicionar novo personagem = criar ficha com has_buster = true/false.
	if current_character.has_buster:
		arm_base_layer.initialize(self)
		buster_layer.initialize(self)
		charge_system.initialize(self)

	visual_library.initialize(self)
	state_machine.initialize(self)

	# Medidas do corpo vêm da ficha. Zera o cache: trocar de personagem muda o tamanho
	# mesmo que o perfil (em pé) seja o mesmo.
	_collision_stance = -1
	apply_collision_stance(PlayerCharacterData.Stance.STAND)

	print("✅ Personagem carregado: %s" % current_character.display_name)
	if current_armor:
		print("✅ Armadura: " + current_armor.armor_name)
		ArmorManager._recalculate_capabilities()
	else:
		print("❌ Armadura não carregada")


# ============================================================
# CHARACTER SWITCH — via signal de CharacterManagement
# ============================================================

## Chamado por CharacterManagement.character_switched.
## HPRegistry já carregou o snapshot correto antes deste signal (via character_pre_switch).
func _on_character_switched(new_id: StringName) -> void:
	print("[Player] Trocando para → %s" % new_id)

	current_character = CharacterManagement.get_active_data()
	if not current_character:
		push_error("[Player] _on_character_switched: data nula para id '%s'" % new_id)
		return

	current_armor = current_character.get_default_armor()

	arm_base_layer.reset()
	buster_layer._cancel()

	ArmorManager.reset_for_player_switch()

	for node in _layer_nodes.values():
		node.visible = false

	_setup_character()

	state_machine.change_state("Intro")
	can_control = true


## Re-inicializa o personagem atual sem trocar de personagem.
## Usado por checkpoints e debug.
func reinitialize() -> void:
	current_character = CharacterManagement.get_active_data()
	if not current_character:
		return
	current_armor = current_character.get_default_armor()

	for node in _layer_nodes.values():
		node.visible = false

	visual_library._def_cache.clear()
	_setup_character()


# ============================================================
# LAYERS
# ============================================================

func _init_layer_nodes() -> void:
	_layer_nodes = {
		"head": layer_head,
		"body": layer_body,
		"arms": layer_arms,
		"legs": layer_legs,
	}
	for node in _layer_nodes.values():
		node.visible = false


func _get_layer_nodes() -> Dictionary:
	return _layer_nodes


func apply_armor() -> void:
	for node in _layer_nodes.values():
		node.visible = false
	previous_armor = current_armor


func change_animation_set(action: String) -> void:
	if not current_character or not current_armor:
		return
	_load_skin_swap(action)


func _load_skin_swap(action: String) -> void:
	var folder = current_character.base_folder
	if not current_armor.animation_folder_override.is_empty():
		folder = current_armor.animation_folder_override

	var path = "res://resources/animations/" + folder + "_" + action + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("⚠️ SpriteFrames não encontrado: " + path)
		return

	var frames = load(path) as SpriteFrames
	if frames:
		sprite.sprite_frames = frames
	else:
		push_warning("⚠️ Falha ao carregar: " + path)


func set_facing(right: bool) -> void:
	if facing_right == right:
		return

	facing_right = right
	sprite.flip_h = not right
	wall_ray.target_position.x = abs(wall_ray.target_position.x) * (1 if right else -1)

	for node in _layer_nodes.values():
		node.flip_h = not right


func reset_momentum() -> void:
	horizontal_momentum = 0.0
	

##### ========== HELPERS PÚBLICOS ========== ######

## Chamado pela porta (MMX_Door) ao detectar o player entrando.
## Trava o boneco numa translação forçada até a porta chamar
## exit_forced_movement() (ao detectar que o player já passou).
func enter_forced_movement(direction: Vector2, speed: float) -> void:
	forced_move_direction = direction
	forced_move_speed = speed
	state_machine.change_state("ForcedMovement")
 
 
## Chamado pela porta ao detectar que o player já atravessou
## (body_exited). A partir daqui, gravidade natural assume — sem
## direção forçada, mas ainda sem controle do jogador (ENTERING_ARENA
## continua ativo até o ArenaFloorTrigger).
func exit_forced_movement() -> void:
	state_machine.change_state("Fall")
