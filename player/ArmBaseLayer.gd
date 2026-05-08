# player/ArmBaseLayer.gd
extends Node

@onready var arm_sprite: AnimatedSprite2D = $"../ArmBaseSprite"

var _player: Player                           = null
var _active: bool                             = true
var _hidden_by_buster: bool                   = false
var _current_arm_data: StateBaseArmVisualData = null
var _in_transition: bool                      = false   # ← FLAG CRÍTICA

const DISABLED_STATES: Array[String] = ["Intro", "Equip"]

# ============================================================
# SETUP
# ============================================================

func _ready() -> void:
	arm_sprite.visible = false

func initialize(player: Player) -> void:
	_player       = player
	_active       = true
	_in_transition = false
	_hidden_by_buster = false
	_current_arm_data = null

	# Zero não usa ArmBaseLayer — esconde e desativa
	if GameManager.current_player != "X":
		_active = false
		arm_sprite.visible = false
		return

	arm_sprite.visible = false


func reset() -> void:
	_active           = false
	_in_transition    = false
	_hidden_by_buster = false
	_current_arm_data = null
	arm_sprite.visible = false
	# Desconecta callbacks pendentes
	if arm_sprite.animation_finished.is_connected(_on_transition_finished):
		arm_sprite.animation_finished.disconnect(_on_transition_finished)


# ============================================================
# PROCESS — flip + frame sync (só fora de transição)
# ============================================================

func _process(_delta: float) -> void:
	if not _player or not _active or _hidden_by_buster:
		return

	arm_sprite.flip_h = _player.sprite.flip_h

	# ← SÓ sincroniza frame quando NÃO está em transição
	# Durante transição o AnimatedSprite2D precisa avançar sozinho
	# para emitir animation_finished
	if not _in_transition and arm_sprite.visible and arm_sprite.sprite_frames:
		arm_sprite.frame = _player.sprite.frame

# ============================================================
# API PÚBLICA
# ============================================================

func on_state_changed(state_name: String, arm_data: StateBaseArmVisualData) -> void:
	if state_name in DISABLED_STATES:
		_active = false
		_in_transition = false
		arm_sprite.visible = false
		return

	_active = true

	if _hidden_by_buster:
		_current_arm_data = arm_data
		return

	arm_sprite.visible = true
	apply_arm_data(arm_data)


func apply_arm_data(data: StateBaseArmVisualData) -> void:
	if not data or data.main_file.is_empty():
		arm_sprite.visible = false
		_in_transition = false
		return

	_current_arm_data = data

	# Se o base já passou da transição, braço pula a transição também
	var already_past_transition := _player and not _player.is_transitioning_walk

	var use_trans  := data.has_transition \
		and not data.transition_file.is_empty() \
		and not data.transition_anim.is_empty() \
		and not already_past_transition   # ← sincroniza com o base


	var load_file  := data.transition_file if use_trans else data.main_file
	var first_anim := data.transition_anim  if use_trans else data.main_anim

	var frames := VisualLibrary.load_frames(load_file)
	if not frames:
		arm_sprite.visible = false
		_in_transition = false
		return

	arm_sprite.sprite_frames = frames
	arm_sprite.z_index       = _player.sprite.z_index + 1
	arm_sprite.stop()
	arm_sprite.frame = 0

	if not frames.has_animation(first_anim):
		arm_sprite.visible = false
		_in_transition = false
		return

	if use_trans:
		# Bloqueia sync de frame enquanto a transição roda
		_in_transition = true
		arm_sprite.play(first_anim)

		var main_file := data.main_file
		var main_anim := data.main_anim

		# Desconecta qualquer callback anterior antes de conectar novo
		if arm_sprite.animation_finished.is_connected(_on_transition_finished):
			arm_sprite.animation_finished.disconnect(_on_transition_finished)

		arm_sprite.animation_finished.connect(
			_on_transition_finished.bind(main_file, main_anim),
			CONNECT_ONE_SHOT
		)
	else:
		_in_transition = false
		arm_sprite.play(first_anim)


func _on_transition_finished(main_file: String, main_anim: String) -> void:
	_in_transition = false   # Libera sync de frame
	var mf := VisualLibrary.load_frames(main_file)
	if mf:
		arm_sprite.sprite_frames = mf
	if arm_sprite.sprite_frames and arm_sprite.sprite_frames.has_animation(main_anim):
		arm_sprite.play(main_anim)
	else:
		arm_sprite.visible = false


# ============================================================
# BUSTER HIDE / SHOW
# ============================================================

func on_shoot_started() -> void:
	hide_arm()

func on_shoot_ended() -> void:
	show_arm()

func hide_arm() -> void:
	_hidden_by_buster = true
	arm_sprite.visible = false

func show_arm() -> void:
	_hidden_by_buster = false
	if not _active:
		return
	arm_sprite.visible = true
	if _current_arm_data:
		apply_arm_data(_current_arm_data)
		# Sincroniza 1 frame à frente do sprite base para sensação de continuidade
		if not _in_transition and _player:
			var anim := arm_sprite.animation
			if arm_sprite.sprite_frames and arm_sprite.sprite_frames.has_animation(anim):
				var count := arm_sprite.sprite_frames.get_frame_count(anim)
				if count > 0:
					arm_sprite.frame = (_player.sprite.frame + 1) % count
