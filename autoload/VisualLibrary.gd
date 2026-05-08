# VisualLibrary.gd
extends Node

const DEF_PATH  := "res://player/states/data/{n}_state_def.tres"
const ANIM_PATH := "res://resources/animations/{f}.tres"

var _owner: Node2D = null
var _def_cache: Dictionary = {}

# Getter tipado — código legado do Player não precisa mudar.
var _player: Player:
	get: return _owner as Player


func initialize(owner: Node2D) -> void:
	_owner = owner


static func load_frames(file_name: String) -> SpriteFrames:
	if file_name.is_empty():
		return null
	var char := GameManager.current_player.to_lower()
	var path := ANIM_PATH.format({"f": "spr_" + char + file_name})
	if not ResourceLoader.exists(path):
		push_warning("VisualLibrary: SpriteFrames não encontrado → " + path)
		return null
	return ResourceLoader.load(path) as SpriteFrames


func _get_def(state_name: String) -> StateDefinition:
	var key := state_name.to_lower()
	if _def_cache.has(key):
		return _def_cache[key]
	var path := DEF_PATH.format({"n": key})
	if not ResourceLoader.exists(path):
		_def_cache[key] = null
		return null
	var def := ResourceLoader.load(path) as StateDefinition
	_def_cache[key] = def
	return def


# ============================================================
# play_state
# Simples (Boss/Enemy): toca animação direto no sprite.
# Completo (Player): StateDefinition + layers.
# ============================================================

func play_state(state_name: String) -> void:
	if not _owner:
		push_error("VisualLibrary: owner não inicializado!")
		return

	if not _owner is Player:
		_play_sprite_direct(state_name)
		return

	var def := _get_def(state_name)
	if not def or not def.visual_data:
		push_warning("VisualLibrary: sem visual_data para → " + state_name)
		return

	var vd := def.visual_data
	_apply_base(vd.base, false)

	if GameManager.current_player == "X":
		if _player.arm_base_layer:
			_player.arm_base_layer.on_state_changed(state_name, vd.base_arm)
		if _player.buster_layer:
			_player.buster_layer.on_state_changed(state_name, vd)
		ArmorManager.on_visual_state_changed(vd.armor)


func _play_sprite_direct(anim_name: String) -> void:
	var sp := _owner.get_node_or_null("Sprite") as AnimatedSprite2D
	if not sp or not sp.sprite_frames:
		return
	if sp.sprite_frames.has_animation(anim_name):
		sp.play(anim_name)


# ============================================================
# apply_anim_to_all_layers
# ============================================================

func apply_anim_to_all_layers(anim_name: String) -> void:
	if not _owner:
		return
	if not _owner is Player:
		_play_sprite_direct(anim_name)
		return

	if _player.sprite.sprite_frames \
	and _player.sprite.sprite_frames.has_animation(anim_name) \
	and _player.sprite.animation != anim_name:
		_player.sprite.play(anim_name)

	if _player.arm_base_layer:
		var arm: AnimatedSprite2D = _player.arm_base_layer.arm_sprite
		if arm.sprite_frames and arm.sprite_frames.has_animation(anim_name) \
		and arm.animation != anim_name:
			arm.play(anim_name)

	for slot in ArmorManager.get_equipped_pieces():
		var node: AnimatedSprite2D = _player._get_layer_nodes().get(slot)
		if not node or not node.visible or not node.sprite_frames:
			continue
		if node.sprite_frames.has_animation(anim_name) and node.animation != anim_name:
			node.play(anim_name)

	if _player.buster_layer:
		var bs: AnimatedSprite2D = _player.buster_layer.buster_sprite
		if bs and bs.visible and bs.sprite_frames \
		and bs.sprite_frames.has_animation(anim_name) \
		and _player.sprite.animation != anim_name:
			_player.sprite.play(anim_name)


# ============================================================
# SHOOT — Player only
# ============================================================

func apply_shoot_base(state_name: String) -> void:
	var def := _get_def(state_name)
	if not def or not def.visual_data or not def.visual_data.base:
		return
	_apply_base(def.visual_data.base, true, false)


func restore_base(state_name: String) -> void:
	var def := _get_def(state_name)
	if not def or not def.visual_data or not def.visual_data.base:
		return
	var data := def.visual_data.base
	var sp   := _player.sprite
	if sp.animation_finished.is_connected(_on_base_transition_finished):
		sp.animation_finished.disconnect(_on_base_transition_finished)
	if sp.animation_finished.is_connected(_on_shoot_oneshot_finished):
		sp.animation_finished.disconnect(_on_shoot_oneshot_finished)
	var frames := load_frames(data.main_file)
	if not frames:
		return
	var saved_frame := sp.frame
	sp.sprite_frames = frames
	_player.is_transitioning_walk = false
	if frames.has_animation(data.main_anim):
		sp.play(data.main_anim)
		var count := frames.get_frame_count(data.main_anim)
		if count > 0:
			sp.frame = saved_frame % count


# ============================================================
# REINICIALIZAR — troca de personagem
# ============================================================

func reinitialize_for_current_player(new_player: Player) -> void:
	if not new_player:
		push_error("VisualLibrary: Player node é nulo!")
		return
	initialize(new_player)
	_def_cache.clear()
	print("VisualLibrary: Reinicializado para → ", GameManager.current_player)
	var current_state := ""
	if new_player.has_method("get_current_state_name"):
		current_state = new_player.get_current_state_name()
	if current_state.is_empty():
		current_state = "Idle"
	play_state(current_state)
	if new_player.sprite:
		new_player.sprite.stop()
	if new_player.arm_base_layer and new_player.arm_base_layer.has_method("on_state_changed"):
		new_player.arm_base_layer.on_state_changed(current_state, null)
	if new_player.buster_layer and new_player.buster_layer.has_method("on_state_changed"):
		new_player.buster_layer.on_state_changed(current_state, null)


func await_frame(sp: AnimatedSprite2D, target_frame: int) -> void:
	while sp.frame < target_frame:
		await sp.frame_changed


# ============================================================
# INTERNO — base visual (Player only)
# ============================================================

func _apply_base(data: StateBaseVisualData, is_shooting: bool, sync_to_current: bool = false) -> void:
	if not data or not _player:
		return
	var file       := ""
	var has_trans  := false
	var trans_anim := ""
	var main_anim  := ""
	var is_oneshot := false

	if is_shooting and not data.shoot_file.is_empty():
		file       = data.shoot_file
		has_trans  = not data.shoot_transition_anim.is_empty() and _player.is_transitioning_walk
		trans_anim = data.shoot_transition_anim
		main_anim  = data.shoot_main_anim
		is_oneshot = not data.is_loop
	else:
		file       = data.main_file
		has_trans  = data.has_transition \
			and not data.transition_file.is_empty() \
			and not data.transition_anim.is_empty()
		trans_anim = data.transition_anim
		main_anim  = data.main_anim

	var frames := load_frames(file)
	if not frames:
		return

	var sp          := _player.sprite
	var saved_frame := sp.frame
	sp.sprite_frames = frames
	sp.stop()
	sp.frame = 0

	if sp.animation_finished.is_connected(_on_base_transition_finished):
		sp.animation_finished.disconnect(_on_base_transition_finished)
	if sp.animation_finished.is_connected(_on_shoot_oneshot_finished):
		sp.animation_finished.disconnect(_on_shoot_oneshot_finished)

	if has_trans and frames.has_animation(trans_anim):
		_player.is_transitioning_walk = true
		sp.play(trans_anim)
		sp.animation_finished.connect(
			_on_base_transition_finished.bind(sp, data.main_file, main_anim, is_oneshot, sync_to_current, saved_frame),
			CONNECT_ONE_SHOT
		)
	else:
		_player.is_transitioning_walk = false
		if frames.has_animation(main_anim):
			sp.play(main_anim)
			if sync_to_current:
				var count := frames.get_frame_count(main_anim)
				if count > 0:
					sp.frame = saved_frame % count
			if is_oneshot:
				sp.animation_finished.connect(_on_shoot_oneshot_finished, CONNECT_ONE_SHOT)


func _on_base_transition_finished(sp: AnimatedSprite2D, main_file: String, main_anim: String, is_oneshot: bool, sync_to_current: bool, saved_frame: int) -> void:
	_player.is_transitioning_walk = false
	var mf := load_frames(main_file)
	if mf:
		sp.sprite_frames = mf
	if sp.sprite_frames and sp.sprite_frames.has_animation(main_anim):
		sp.play(main_anim)
		if sync_to_current:
			var count := sp.sprite_frames.get_frame_count(main_anim)
			if count > 0:
				sp.frame = saved_frame % count
		if is_oneshot:
			sp.animation_finished.connect(_on_shoot_oneshot_finished, CONNECT_ONE_SHOT)


func _on_shoot_oneshot_finished() -> void:
	if _player and _player.buster_layer:
		_player.buster_layer.end_shoot_external()


func _apply_buster_direct(data: StateBusterVisualData) -> void:
	if not data or not _player or not _player.buster_layer:
		return
	var bs: AnimatedSprite2D = _player.buster_layer.buster_sprite
	if not bs:
		return
	var use_trans  := data.has_transition and not data.transition_file.is_empty()
	var file       := data.transition_file if use_trans else data.main_file
	var trans_anim := data.transition_anim
	var main_anim  := data.main_anim
	var frames := load_frames(file)
	if not frames:
		return
	bs.sprite_frames = frames
	bs.z_index       = _player.sprite.z_index + 2
	bs.flip_h        = _player.sprite.flip_h
	bs.stop()
	bs.frame   = 0
	bs.visible = true
	if use_trans and frames.has_animation(trans_anim):
		bs.play(trans_anim)
		var main_file := data.main_file
		bs.animation_finished.connect(
			func():
				var mf := load_frames(main_file)
				if mf: bs.sprite_frames = mf
				if bs.sprite_frames and bs.sprite_frames.has_animation(main_anim):
					bs.play(main_anim),
			CONNECT_ONE_SHOT
		)
	else:
		if frames.has_animation(main_anim):
			bs.play(main_anim)


func apply_sequence_step(step: VisualSequenceStepData) -> void:
	if not step or not _player:
		return
	if step.base_visual:
		_apply_base(step.base_visual, false)
	if step.base_arm_visual and _player.arm_base_layer:
		_player.arm_base_layer.apply_arm_data(step.base_arm_visual)
	if step.armor_visual:
		ArmorManager.on_visual_state_changed(step.armor_visual)
