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

@export var current_character: PlayerCharacterData
@export var current_armor: ArmorData
@export var previous_armor: ArmorData
@export var current_weapon: WeaponData

var forced_move_direction: Vector2 = Vector2.ZERO
var forced_move_speed: float = 0.0


@onready var state_machine: StateMachine = $StateMachine
@onready var wall_ray: RayCast2D = $WallRay

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
# SETUP
# ============================================================

func play_stage_intro() -> void:
	state_machine.change_state("Intro")


## Inicializa todos os sistemas para o current_character atual.
## Compartilhado entre _ready() e _on_character_switched().
func _setup_character() -> void:
	ArmorManager.on_player_ready(self)

	# Capability flags substituem if ["X","Zero"] hardcoded.
	# Adicionar novo personagem = criar ficha com has_buster = true/false.
	if current_character.has_buster:
		arm_base_layer.initialize(self)
		buster_layer.initialize(self)
		charge_system.initialize(self)

	visual_library.initialize(self)
	state_machine.initialize(self)

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
