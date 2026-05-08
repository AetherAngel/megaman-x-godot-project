# stages/objects/SecretCapsule.gd
extends Node2D

@export var cutscene_x:       CutsceneData
@export var cutscene_zero:    CutsceneData
@export var grant_equip_time: float = 0.75

@onready var sprite:      AnimatedSprite2D = $Sprite
@onready var detect_area: Area2D           = $DetectArea
@onready var equip_area:  Area2D           = $EquipArea

enum Phase { IDLE, BLOCKED, TALKING, OPENING, DR_LIGHT_A, IN_TALK, CAN_WALK_IN, WAITING_EQUIP, GRANTING, DONE }
var _phase: Phase = Phase.IDLE

var _player_in_detect: bool = false
var _player_in_equip:  bool = false
var _armor_granted:    bool = false

var _blocked_dialogue: DialogueData = null


func _ready() -> void:
	add_to_group("secret_capsule")
	sprite.sprite_frames = load("res://resources/animations/spr_light_capsule.tres")

	equip_area.monitoring = false

	detect_area.body_entered.connect(_on_detect_entered)
	detect_area.body_exited.connect(_on_detect_exited)
	equip_area.body_entered.connect(_on_equip_entered)
	equip_area.body_exited.connect(_on_equip_exited)

	_setup_blocked_dialogue()
	_setup_initial_state()


func _setup_initial_state() -> void:
	# X com peça equipada → começa direto no frame 8 da Offline parado
	if GameManager.current_player == "X" and ArmorManager.has_any_piece():
		_phase = Phase.BLOCKED
		sprite.play("Offline")
		sprite.stop()
		sprite.frame = 8
	else:
		sprite.play("Idle")


func _setup_blocked_dialogue() -> void:
	var line1        = DialogueLine.new()
	line1.speaker    = "X"
	line1.mugshot    = "x_placeholder"
	line1.text       = "Hmmm...."

	var line2        = DialogueLine.new()
	line2.speaker    = "X"
	line2.mugshot    = "x_placeholder"
	line2.text       = "I feel like I should come back here without any armor equipped."

	_blocked_dialogue          = DialogueData.new()
	_blocked_dialogue.lines    = [line1, line2]


# =========================
# DETECT AREA
# =========================
func _on_detect_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_detect = true

	match _phase:
		Phase.BLOCKED:
			TalkManager.start(_blocked_dialogue)
		Phase.IDLE:
			_start_sequence()


func _on_detect_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_detect = false


# =========================
# SEQUÊNCIA PRINCIPAL
# =========================
func _start_sequence() -> void:
	GameManager.set_input_mode(GameManager.InputMode.MENU)
	InputManager.can_process_player_input = false

	# Opening
	_phase = Phase.OPENING
	sprite.play("Opening")
	await sprite.animation_finished

	# DrLightA
	_phase = Phase.DR_LIGHT_A
	sprite.play("DrLightA")
	await sprite.animation_finished

	# InTalk (loop) + diálogo
	_phase = Phase.IN_TALK
	sprite.play("InTalk")

	var cutscene: CutsceneData
	match GameManager.current_player:
		"Zero": cutscene = cutscene_zero
		_:      cutscene = cutscene_x

	if not cutscene:
		push_warning("SecretCapsule: CutsceneData não configurada para " + GameManager.current_player)
	else:
		_inject_player_mugshot(cutscene)
		CutsceneSequencer.play(cutscene, Callable())
		await TalkManager.dialogue_finished

	# CanWalkIn — Dr.Light desaparece
	_phase = Phase.CAN_WALK_IN
	sprite.play("CanWalkIn")
	await sprite.animation_finished

	# Para no último frame — libera o player
	sprite.stop()
	_phase = Phase.WAITING_EQUIP
	GameManager.set_input_mode(GameManager.InputMode.PLAYER)
	InputManager.can_process_player_input = true
	equip_area.monitoring = true


func _inject_player_mugshot(cutscene: CutsceneData) -> void:
	for step in cutscene.steps:
		if step is StepDialogue:
			for line in (step as StepDialogue).dialogue.lines:
				if line.speaker in ["X", "Zero"]:
					match GameManager.current_player:
						"Zero": line.mugshot = "zero_placeholder"
						_:      line.mugshot = "x_placeholder"


# =========================
# EQUIP AREA
# =========================
func _on_equip_entered(body: Node) -> void:
	if not body.is_in_group("player") or _phase != Phase.WAITING_EQUIP:
		return
	_player_in_equip = true
	_start_granting()


func _on_equip_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_equip = false
	if _phase == Phase.GRANTING and _armor_granted:
		_go_offline()


func _start_granting() -> void:
	_phase = Phase.GRANTING
	GameManager.set_input_mode(GameManager.InputMode.MENU)
	InputManager.can_process_player_input = false

	sprite.play("GrantingPart")

	await get_tree().create_timer(grant_equip_time).timeout
	_grant_armor()

	await sprite.animation_finished
	sprite.stop()

	if not _player_in_equip:
		_go_offline()


func _grant_armor() -> void:
	if _armor_granted:
		return
	_armor_granted = true

	ArmorManager.equip_secret_armor()

	GameManager.set_input_mode(GameManager.InputMode.PLAYER)
	InputManager.can_process_player_input = true


# =========================
# OFFLINE
# =========================
func _go_offline() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	equip_area.monitoring  = false
	detect_area.monitoring = false

	sprite.play("Offline")
	await sprite.animation_finished
	sprite.stop()
