# stages/objects/LightCapsule.gd
extends Node2D

@export var cutscene_x: CutsceneData
@export var cutscene_zero: CutsceneData
@export var armor_slot: String = "legs"
@export var grant_equip_time: float = 0.75


@onready var sprite: AnimatedSprite2D = $Sprite
@onready var detect_area: Area2D = $DetectArea
@onready var equip_area: Area2D = $EquipArea
@onready var ceiling_area: StaticBody2D = $CeilingCollision
@onready var closed_collision: StaticBody2D = $ClosedCollision

enum Phase {
	IDLE,
	TALKING,
	OPENING,
	DR_LIGHT_A,
	IN_TALK,
	CAN_WALK_IN,
	WAITING_EQUIP,
	GRANTING,
	DONE
}

var _phase: Phase = Phase.IDLE
var _player_in_detect: bool = false
var _player_in_equip: bool = false
var _armor_granted: bool = false


func _ready() -> void:
	add_to_group("light_capsule")
	closed_collision.get_node("CollisionShape2D").set_deferred("disabled", true)
	sprite.sprite_frames = load("res://resources/animations/spr_drlight_capsule.tres")

	equip_area.monitoring = false

	detect_area.body_entered.connect(_on_detect_entered)
	detect_area.body_exited.connect(_on_detect_exited)
	equip_area.body_entered.connect(_on_equip_entered)
	equip_area.body_exited.connect(_on_equip_exited)

	# Verifica imediatamente se o player já tem essa peça — vai offline se sim
	# Usa call_deferred pois o ArmorManager pode ainda estar inicializando
	call_deferred("_check_already_equipped")


func _check_already_equipped() -> void:
	# Zero nunca usa peças de armadura do X
	# if GameManager.current_player == "Zero":
		#_go_offline_instant()
		# return

	if ArmorManager.has_piece(armor_slot):
		_go_offline_instant()
		return

	# Peça ainda não equipada — inicia normalmente
	sprite.play("Idle")

func resolve_collisions_() -> void:
	 # Cápsula fechada — troca collision aberta pela fechada
	ceiling_area.queue_free()
	closed_collision.get_node("CollisionShape2D").disabled = false

func _go_offline_instant() -> void:
	_phase          = Phase.DONE
	_armor_granted  = true
	equip_area.monitoring  = false
	detect_area.monitoring = false
	sprite.sprite_frames   = load("res://resources/animations/spr_drlight_capsule.tres")
	sprite.stop()
	# Frame do sprite Offline estático (frame 8, igual ao _go_offline normal)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("Offline"):
		sprite.play("Offline")
		await sprite.animation_finished
		sprite.stop()
		sprite.frame = 8
		resolve_collisions_()
	else:
		sprite.frame = 8
		resolve_collisions_()


# =========================
# DETECT AREA
# =========================
func _on_detect_entered(body: Node) -> void:
	if not body.is_in_group("player") or _phase != Phase.IDLE:
		return
	_player_in_detect = true

	var player = body as Player
	if player:
		player.velocity = Vector2.ZERO
		player.can_control = false
		if player.is_on_floor():
			player.state_machine.change_state("Idle")
		else:
			player.state_machine.change_state("Fall")

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

	_phase = Phase.OPENING
	sprite.play("Opening")
	await sprite.animation_finished

	var player = get_tree().get_first_node_in_group("player")
	if player and not player.facing_right:
		sprite.flip_h = true

	_phase = Phase.DR_LIGHT_A
	sprite.play("DrLightA")
	await sprite.animation_finished

	_phase = Phase.IN_TALK
	sprite.play("InTalk")
	SoundManager.play_music("dr_light")

	var cutscene: CutsceneData
	match GameManager.current_player:
		"Zero": cutscene = cutscene_zero
		_:      cutscene = cutscene_x

	if not cutscene:
		push_warning("LightCapsule: CutsceneData não configurada para " + GameManager.current_player)
	else:
		_inject_player_mugshot(cutscene)
		TalkManager.start(cutscene.steps[0].dialogue)
		await TalkManager.dialogue_finished

	_phase = Phase.CAN_WALK_IN
	sprite.play("CanWalkIn")
	await sprite.animation_finished
	SoundManager.stop_music()
	SoundManager.play_music("stage_test")

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
	_walk_to_center_then_grant(body)


func _walk_to_center_then_grant(body: Node) -> void:
	var player = body as Player
	if not player:
		_start_granting()
		return

	var target_x = equip_area.global_position.x
	if not player.facing_right:
		target_x -= 4.0

	var walk_speed = 30.0
	while abs(player.global_position.x - target_x) > 2.0:
		var dir = sign(target_x - player.global_position.x)
		var dirwalk: float = dir * walk_speed
		player.set_horizontal_speed(dirwalk)
		player.set_facing(dir > 0)
		await get_tree().process_frame

	player.velocity = Vector2.ZERO
	player.set_facing(false)
	_start_granting()


func _on_equip_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_equip = false
	if _phase == Phase.GRANTING and _armor_granted:
		_go_offline()
		resolve_collisions_()


func _start_granting() -> void:
	_phase = Phase.GRANTING
	GameManager.set_input_mode(GameManager.InputMode.MENU)
	InputManager.can_process_player_input = false

	sprite.play("GrantingPart")
	await sprite.animation_finished
	sprite.stop()

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_go_offline()
		return

	var equip_state = player.state_machine.states.get("Equip")
	if not equip_state:
		_go_offline()
		return

	equip_state.equip_finished.connect(_grant_armor, CONNECT_ONE_SHOT)
	equip_state.equip_animation_done.connect(_on_equip_animation_done, CONNECT_ONE_SHOT)

	player.state_machine.change_state("Equip")


func _on_equip_animation_done() -> void:
	if not _player_in_equip:
		_go_offline()


func _grant_armor() -> void:
	if _armor_granted:
		return
	_armor_granted = true

	match GameManager.current_player:
		"X":
			# X equipa visualmente
			ArmorManager.equip_piece(armor_slot)
		"Zero":
			# Zero apenas coleta para o X — sem visual
			ArmorManager.collect_piece_for_x(armor_slot)

	# Salva imediatamente para persistir entre sessões e personagens
	SaveSystem.collect_game_data()
	SaveSystem.save()
	print("💾 Peça '%s' coletada e salva!" % armor_slot)


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
	sprite.frame = 8
