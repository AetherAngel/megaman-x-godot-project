# player/BusterLayer.gd
extends Node

@onready var buster_sprite: AnimatedSprite2D = $"../BusterSprite"

var _player: Player              = null
var _active: bool                = true
var _shooting: bool              = false
var _in_transition: bool         = false   # ← FLAG CRÍTICA
var _current_visual: StateVisualData = null
var _current_state_name: String  = ""

# Lifetime system
var _lifetime: float             = 0.0
var _add_cooldown: float         = 0.0
const LIFETIME_BASE: float       = 1.0
const LIFETIME_ADD: float        = 0.5
const ADD_COOLDOWN: float        = 0.3

const DISABLED_STATES: Array[String] = ["Intro", "Equip"]

# ============================================================
# SETUP
# ============================================================

func _ready() -> void:
	buster_sprite.visible = false

func initialize(player: Player) -> void:
	_player = player

# ============================================================
# PROCESS — lifetime + flip (sem sync de frame)
# ============================================================

func _process(delta: float) -> void:
	if not _player:
		return

	buster_sprite.flip_h = _player.sprite.flip_h

	if not _shooting:
		return

	if _add_cooldown > 0.0:
		_add_cooldown -= delta

	_lifetime -= delta
	if _lifetime <= 0.0:
		_end_shoot()

# ============================================================
# API PÚBLICA
# ============================================================

func on_state_changed(state_name: String, visual: StateVisualData) -> void:
	# Estado mudou enquanto atirava → encerra shoot mas NÃO restaura o base
	# (play_state já aplicou o visual do novo estado antes de chegar aqui)
	if _shooting and state_name != _current_state_name:
		_end_shoot(true)   # skip_restore = true


	_current_state_name = state_name
	_current_visual     = visual

	if state_name in DISABLED_STATES:
		_active = false
		_cancel()
		return

	_active = true

	# Só reaplica o buster se AINDA estiver atirando após o end_shoot acima


	if _shooting and visual:
		_apply_buster_visual(visual)


func start_shoot() -> void:
	if not _active:
		return
	if not _current_visual or not _current_visual.buster:
		return

	if _shooting:
		if _add_cooldown <= 0.0:
			_lifetime     += LIFETIME_ADD
			_add_cooldown  = ADD_COOLDOWN
		return

	_shooting     = true
	_lifetime     = LIFETIME_BASE
	_add_cooldown = 0.0

	_apply_buster_visual(_current_visual)
	_player.arm_base_layer.on_shoot_started()
	_player.pressed_shoot_designedbutton = true

# ============================================================
# INTERNO
# ============================================================

func _apply_buster_visual(visual: StateVisualData) -> void:
	if not visual or not visual.buster:
		return

	var bd: StateBusterVisualData = visual.buster
	
		# Se o base já passou da transição, pula a transição do buster também
	var already_past_transition := not _player.is_transitioning_walk

	var use_trans  := bd.has_transition \
		and not bd.transition_file.is_empty() \
		and not bd.transition_anim.is_empty() \
		and not already_past_transition   # ← pula se base já está no main


	var load_file  := bd.transition_file if use_trans else bd.main_file
	var first_anim := bd.transition_anim  if use_trans else bd.main_anim
	var main_anim  := bd.main_anim
	var main_file  := bd.main_file

	var frames := VisualLibrary.load_frames(load_file)
	if not frames:
		return

	buster_sprite.sprite_frames = frames
	buster_sprite.z_index       = _player.sprite.z_index + 2
	buster_sprite.flip_h        = _player.sprite.flip_h
	buster_sprite.stop()
	buster_sprite.frame         = 0
	buster_sprite.visible       = true

	if not frames.has_animation(first_anim):
		return

	if use_trans:
		_in_transition = true
		buster_sprite.play(first_anim)

		# Desconecta callback anterior se existir
		if buster_sprite.animation_finished.is_connected(_on_buster_transition_finished):
			buster_sprite.animation_finished.disconnect(_on_buster_transition_finished)

		buster_sprite.animation_finished.connect(
			_on_buster_transition_finished.bind(main_file, main_anim),
			CONNECT_ONE_SHOT
		)
	else:
		_in_transition = false
		buster_sprite.play(first_anim)

	# Base em modo shoot
	_player.visual_library.apply_shoot_base(_current_state_name)

	# Armor arms em modo buster
	if visual.armor:
		ArmorManager.on_buster_started(visual.armor)


func _on_buster_transition_finished(main_file: String, main_anim: String) -> void:
	_in_transition = false
	var mf := VisualLibrary.load_frames(main_file)
	if mf:
		buster_sprite.sprite_frames = mf
	if buster_sprite.sprite_frames and buster_sprite.sprite_frames.has_animation(main_anim):
		buster_sprite.play(main_anim)


func _end_shoot(skip_restore: bool = false) -> void:
	_shooting      = false
	_lifetime      = 0.0
	_in_transition = false
	_player.pressed_shoot_designedbutton = false
	buster_sprite.visible = false

	# Desconecta callback pendente se o tiro acabar antes da transição
	if buster_sprite.animation_finished.is_connected(_on_buster_transition_finished):
		buster_sprite.animation_finished.disconnect(_on_buster_transition_finished)
	# Não restaura se o estado já mudou — play_state já aplicou o novo visual
	if not skip_restore:
		_player.visual_library.restore_base(_current_state_name)


	if _current_visual and _current_visual.armor:
		ArmorManager.on_buster_ended(_current_visual.armor)

	_player.arm_base_layer.on_shoot_ended()


func _cancel() -> void:
	_shooting      = false
	_lifetime      = 0.0
	_in_transition = false
	buster_sprite.visible = false
	_player.pressed_shoot_designedbutton = false

	if buster_sprite.animation_finished.is_connected(_on_buster_transition_finished):
		buster_sprite.animation_finished.disconnect(_on_buster_transition_finished)



# Chamado pela VisualLibrary quando animação oneshot do base termina
func end_shoot_external() -> void:
	if _shooting:
		_end_shoot()
