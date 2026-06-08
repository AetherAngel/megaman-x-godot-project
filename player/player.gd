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



func _ready() -> void:
	sprite.position = Vector2.ZERO
	
	#sprite.animation_changed.connect(func():
		#print("🎬 sprite animation → '%s'" % sprite.animation)
		#for frame in get_stack():
			#print("   %s:%d @ %s" % [frame["source"], frame["line"], frame["function"]])
		#print("---")
#)

	process_priority = 0
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")

	_init_layer_nodes()
	_load_player_data()
	
	ArmorManager.on_player_ready(self)

	if GameManager.current_player in ["X", "Zero"]:
		arm_base_layer.initialize(self)
		buster_layer.initialize(self)
		charge_system.initialize(self)

	visual_library.initialize(self)
	state_machine.initialize(self)

	print("✅ Personagem carregado: " + str(GameManager.current_player))
	if current_armor:
		print("✅ Armadura: " + current_armor.armor_name)
		ArmorManager._recalculate_capabilities()
		print("✅ Armadura: " + current_armor.armor_name)
	else:
		print("❌ Armadura não carregada")
	
	

	call_deferred("play_stage_intro")


# ============================================================
# HOOK DE ESTADO — chamado pelo Actor._physics_process
# entre a gravidade e o move_and_slide.
#
# Ordem por frame (definida em Actor):
#   1. _apply_gravity        ← Actor
#   2. _process_state        ← AQUI (state machine modifica velocity)
#   3. _process_invulnerability
#   4. _process_movement     ← Character (move_and_slide + pixel snap)
#   5. _process_zero_health
#   6. _update_time_since_floor
# ============================================================
func _process_state(delta: float) -> void:
	if state_machine:
		state_machine.process_state(delta)

	ArmorManager.sync_frame(self)
	wall_slide_cooldown = max(0.0, wall_slide_cooldown - delta)
	wall_kick_grace     = max(0.0, wall_kick_grace - delta)


# ============================================================
# SETUP
# ============================================================

func play_stage_intro() -> void:
	state_machine.change_state("Intro")


func _load_player_data() -> void:
	match GameManager.current_player:
		
		"Zero":
			char_path  = "res://player/data/zero_character.tres"
			armor_path =  "res://player/data/armors/normal_zero.tres"
		"Axl":
			char_path  = "res://player/data/axl_character.tres"
			armor_path = "res://player/data/armors/normal_axl.tres"
		_:
			char_path  = "res://player/data/x_character.tres"
			armor_path = "res://player/data/armors/armor_normal.tres"

	current_character = load(char_path)
	current_armor     = load(armor_path)

	match GameManager.current_player:
		"Zero":
			current_character.skill_tree = load("res://player/data/skilltree/zero_skilltree.tres")
		_:
			current_character.skill_tree = load("res://player/data/skilltree/x_skilltree.tres")


func _load_actual_data_and_armor() -> void:
	
	match GameManager.current_player:
		
		"Zero":
			armor_path =  bsarmrpath + current_armor.armor_name + ".tres"
		"Axl":
			armor_path = bsarmrpath + current_armor.armor_name + ".tres"
		_:
			armor_path = bsarmrpath + current_armor.armor_name + ".tres"

	current_character = load(char_path)
	current_armor     = load(armor_path)
	

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


func on_character_changed() -> void:
	print("Player: trocando para → ", GameManager.current_player)

	_load_player_data()

	arm_base_layer.reset()
	buster_layer._cancel()

	ArmorManager.reset_for_player_switch()
	ArmorManager.on_player_ready(self)

	if GameManager.current_player in ["X", "Zero"]:
		arm_base_layer.initialize(self)
		buster_layer.initialize(self)
		charge_system.initialize(self)

	visual_library._def_cache.clear()
	visual_library.initialize(self)

	for node in _layer_nodes.values():
		node.visible = false

	state_machine.change_state("Intro")
