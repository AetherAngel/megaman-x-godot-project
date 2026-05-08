# autoload/ArmorManager.gd
extends Node

var _player: Player
var _equipped_pieces: Array[String] = []
var _sync_paused: bool = false
var _block_visual_sync: bool = false

# Sistema Data-Driven
var _current_armor_data: StateArmorVisualData = null
var _is_buster_active: bool = false
var _in_transition_slots: Dictionary = {}  # slot → bool

# Nova Strike
var _nova_strike_energy: float = 0.0
var _nova_strike_used: bool = false

const FOURTH_ARMOR_PATH   = "res://player/data/armors/fourth_armor.tres"
const NORMAL_ARMOR_PATH   = "res://player/data/armors/armor_normal.tres"
const ULTIMATE_ARMOR_PATH = "res://player/data/armors/ultimate_armor.tres"
const BLACK_ZERO_PATH     = "res://player/data/armors/black_zero.tres"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_refuel_nova_strike(delta)


# =========================
# INICIALIZAÇÃO
# =========================

func on_player_ready(player: Player) -> void:
	_player = player
	_load_from_save()

func reset_for_player_switch() -> void:
	# Esconde todas as layers visuais
	if _player:
		for node in _player._get_layer_nodes().values():
			node.visible = false

	# Limpa estado interno completamente
	_equipped_pieces.clear()
	_current_armor_data    = null
	_is_buster_active      = false
	_in_transition_slots.clear()
	_nova_strike_energy    = 0.0
	_nova_strike_used      = false
	_sync_paused           = false
	_block_visual_sync     = false


func _load_from_save() -> void:
	if not SaveSystem.current_save:
		return

	match GameManager.current_player:
		"X":
			_equipped_pieces = SaveSystem.current_save.x_equipped_pieces.duplicate()
			if not _equipped_pieces.is_empty():
				if SaveSystem.current_save.x_armor_id == "ultimate":
					_apply_armor(ULTIMATE_ARMOR_PATH)
				else:
					_apply_armor(FOURTH_ARMOR_PATH)
				_recalculate_capabilities()
				_nova_strike_energy = _get_energy_max()
				# Notifica ChargeSystem se arms já estava equipado no save
				if "arms" in _equipped_pieces and _player.charge_system:
					_player.charge_system.on_arms_equipped()


		"Zero":
			var zero_armor_id = SaveSystem.current_save.zero_armor_id
			if zero_armor_id == "black_zero" and ResourceLoader.exists(BLACK_ZERO_PATH):
				_player.current_armor = load(BLACK_ZERO_PATH)
				print("✅ Black Zero carregado do save")


# =========================
# EQUIP PEÇA INDIVIDUAL
# =========================
# Coleta uma peça para o X sem equipar visualmente
# Usado pelo Zero quando pega uma cápsula
# Coleta cross-character: Zero pega para o X
# Precisa atualizar tanto o save quanto o estado em memória
# para o switch de personagem carregar corretamente.
func collect_piece_for_x(slot: String) -> void:
	if slot in _equipped_pieces:
		print("⚠️ Peça '%s' já equipada no X" % slot)
		return
	
	if not SaveSystem.current_save:
		push_error("SaveSystem.current_save não existe!")
		return
	
	# 1. Salva no sistema persistente
	if slot not in SaveSystem.current_save.x_equipped_pieces:
		SaveSystem.current_save.x_equipped_pieces.append(slot)
		print("📦 Peça '%s' coletada pelo Zero para o X" % slot)
	
	# 2. Se o X já estiver carregado (raro, mas possível), atualiza também o runtime
	if GameManager.current_player == "X":
		equip_piece(slot)          # Já existe e faz tudo certo
		return
	
	# 3. IMPORTANTE: Mesmo jogando de Zero, marcamos que o X tem peças
	# Para quando trocar de personagem, ele já carregar corretamente
	if not slot in _equipped_pieces:
		_equipped_pieces.append(slot)
	
	# 4. Força salvar
	_save_to_save()
	
	# Opcional: Debug
	print("✅ Estado X atualizado | Peças equipadas: ", _equipped_pieces)

func equip_piece(slot: String) -> void:
	if slot in _equipped_pieces:
		return
	_equipped_pieces.append(slot)
	_save_to_save()
	if not _player:
		return
	# Visual e capabilities só aplicam para X
	if GameManager.current_player == "X":
		_apply_armor(FOURTH_ARMOR_PATH)
		_recalculate_capabilities()
		if not _block_visual_sync and _current_armor_data:
			_apply_slot_from_data(slot, _current_armor_data, false)
		if slot == "arms" and _player.charge_system:
			_player.charge_system.on_arms_equipped()




func equip_full() -> void:
	_equipped_pieces = ["head", "body", "arms", "legs"]
	_save_to_save()
	if not _player:
		return
	_apply_armor(FOURTH_ARMOR_PATH)
	_recalculate_capabilities()
	_nova_strike_energy = _get_energy_max()
	# Reaplica todos os slots com os dados atuais
	if not _block_visual_sync and _current_armor_data:
		for slot in _equipped_pieces:
			_apply_slot_from_data(slot, _current_armor_data, false)
	# Notifica ChargeSystem — arms sempre está no equip_full
	if _player.charge_system:
		_player.charge_system.on_arms_equipped()



func unequip_piece(slot: String) -> void:
	if slot not in _equipped_pieces:
		return
	_equipped_pieces.erase(slot)
	_save_to_save()
	if not _player:
		return
	var node: AnimatedSprite2D = _player._get_layer_nodes().get(slot)
	if node:
		node.visible = false
	_recalculate_capabilities()
	if _equipped_pieces.is_empty():
		if ResourceLoader.exists(NORMAL_ARMOR_PATH):
			_player.current_armor = load(NORMAL_ARMOR_PATH)


# =========================
# EQUIP ARMADURA SECRETA
# =========================

func equip_secret_armor() -> void:
	match GameManager.current_player:
		"X":    _equip_ultimate()
		"Zero": _equip_black_zero()


func _equip_ultimate() -> void:
	if not ResourceLoader.exists(ULTIMATE_ARMOR_PATH):
		push_warning("❌ ultimate_armor.tres não encontrado!")
		return
	_equipped_pieces = ["head", "body", "arms", "legs"]
	if SaveSystem.current_save:
		SaveSystem.current_save.x_equipped_pieces = _equipped_pieces.duplicate()
		SaveSystem.current_save.x_armor_id = "ultimate"
	_apply_armor(ULTIMATE_ARMOR_PATH)
	_recalculate_capabilities()
	_nova_strike_energy = _get_energy_max()
	print("✅ Ultimate Armor equipada!")
	if _current_armor_data:
		for slot in _equipped_pieces:
			_apply_slot_from_data(slot, _current_armor_data, false)


func _equip_black_zero() -> void:
	if not ResourceLoader.exists(BLACK_ZERO_PATH):
		push_warning("❌ black_zero.tres não encontrado!")
		return
	_player.current_armor = load(BLACK_ZERO_PATH)
	if SaveSystem.current_save:
		SaveSystem.current_save.zero_armor_id = "black_zero"
	print("✅ Black Zero equipado!")


# =========================
# EQUIP INTRO
# =========================

func play_equip_intro() -> void:
	if not _player or _equipped_pieces.is_empty():
		return

	var layer_nodes = _player._get_layer_nodes()

	for slot in _equipped_pieces:
		var node: AnimatedSprite2D = layer_nodes.get(slot)
		if not node:
			continue

		# Equip usa path direto pois é uma animação especial única
		var path = "res://resources/animations/spr_x_fourth_" + slot + "_equip.tres"
		if not ResourceLoader.exists(path):
			continue

		var frames = load(path) as SpriteFrames
		if not frames or not frames.has_animation("default"):
			continue

		node.sprite_frames = frames
		node.visible       = true
		node.flip_h        = _player.sprite.flip_h
		node.z_index       = _player.sprite.z_index + 5
		node.stop()
		node.frame = 0
		node.play("default")


# =========================
# CONTROLE DE SYNC
# =========================

func block_visual_sync() -> void:
	_block_visual_sync = true

func unblock_visual_sync() -> void:
	_block_visual_sync = false

func pause_sync() -> void:
	_sync_paused = true

func resume_sync() -> void:
	_sync_paused = false


# =========================
# SISTEMA DATA-DRIVEN
# =========================

func on_visual_state_changed(armor_data: StateArmorVisualData) -> void:
	_current_armor_data = armor_data
	_is_buster_active   = false
	_in_transition_slots.clear()

	if not _can_sync_armor() or not armor_data:
		return

	for slot in _equipped_pieces:
		_apply_slot_from_data(slot, armor_data, false)


func on_buster_started(armor_data: StateArmorVisualData) -> void:
	_is_buster_active = true
	if not _can_sync_armor() or not armor_data:
		return
	for slot in _equipped_pieces:
		# Arms → variante buster, demais slots → variante shoot (se existir)
		_apply_slot_from_data(slot, armor_data, slot == "arms")


func on_buster_ended(armor_data: StateArmorVisualData) -> void:
	_is_buster_active = false
	if not _can_sync_armor() or not armor_data:
		return
	# Restaura todos os slots para o visual normal
	for slot in _equipped_pieces:
		_apply_slot_from_data(slot, armor_data, false)


func _apply_slot_from_data(slot: String, armor_data: StateArmorVisualData, is_buster_arms: bool) -> void:
	var node: AnimatedSprite2D = _player._get_layer_nodes().get(slot)
	if not node:
		return

	# ── Monta paths ─────────────────────────────────────────
	# Normal:       {main_file}_{slot}_{main_action}.tres
	#   ex: "spr_x_fourth" + "_legs_" + "walk" → spr_x_fourth_legs_walk.tres
	#
	# Buster arms:  {buster_file}_{main_action}.tres
	#   ex: "spr_x_fourth_buster" + "_walk"   → spr_x_fourth_buster_walk.tres
	
		# Se o base já passou da transição, armor pula a transição também
	var already_past_transition := not _player.is_transitioning_walk
	var base_path  := "spr_x_"
	var has_trans  := false
	var trans_path := ""
	var main_path  := ""
	var trans_anim := ""
	var main_anim  := ""

	if is_buster_arms and slot == "arms":
		has_trans  = not armor_data.armor_shoot_transition_anim.is_empty() \
			and _player.is_transitioning_walk
		trans_anim = armor_data.armor_shoot_transition_anim
		main_anim  = armor_data.armor_shoot_main_anim
		if has_trans:
			trans_path = "res://resources/animations/" \
				+ base_path + armor_data.buster_transition_file + "_" + armor_data.main_action + ".tres"
		main_path = "res://resources/animations/" \
			+ base_path + armor_data.buster_file + "_" + armor_data.main_action + ".tres"
	elif _is_buster_active and not armor_data.armor_shoot_file.is_empty() and slot != "arms":
		# Slots normais durante shoot — variante shoot (head, body, legs)
		has_trans  = not armor_data.armor_shoot_transition_anim.is_empty() \
			and _player.is_transitioning_walk
		trans_anim = armor_data.armor_shoot_transition_anim
		main_anim  = armor_data.armor_shoot_main_anim
		if has_trans:
			trans_path = "res://resources/animations/" \
				+ base_path + armor_data.armor_shoot_file + "_" + slot + "_" + armor_data.main_action + ".tres"
		main_path = "res://resources/animations/" \
			+ base_path + armor_data.armor_shoot_file + "_" + slot + "_" + armor_data.main_action + ".tres"
	else:
		var raw_has_trans := armor_data.has_transition \
			and not armor_data.transition_file.is_empty() \
			and not armor_data.transition_anim.is_empty()
		# Só usa transição se o base também está em transição
		has_trans  = raw_has_trans and not already_past_transition
		trans_anim = armor_data.transition_anim
		main_anim  = armor_data.main_anim

		if has_trans:
			trans_path = "res://resources/animations/" \
				+ base_path + armor_data.transition_file + "_" + slot + "_" + armor_data.main_action + ".tres"
		main_path = "res://resources/animations/" \
			+ base_path + armor_data.main_file + "_" + slot + "_" + armor_data.main_action + ".tres"

	var load_path  := trans_path if has_trans else main_path
	var first_anim := trans_anim if has_trans else main_anim

	if load_path.is_empty() or not ResourceLoader.exists(load_path):
		node.visible = false
		return

	var frames := ResourceLoader.load(load_path) as SpriteFrames
	if not frames:
		node.visible = false
		return

	node.sprite_frames = frames
	node.visible       = true
	node.z_index       = _player.sprite.z_index + 3
	node.stop()
	node.frame = 0

	if not frames.has_animation(first_anim):
		node.visible = false
		return

	if has_trans:
		_in_transition_slots[slot] = true
		node.play(first_anim)

		if node.animation_finished.is_connected(_on_slot_transition_finished):
			node.animation_finished.disconnect(_on_slot_transition_finished)

		node.animation_finished.connect(
			_on_slot_transition_finished.bind(node, slot, main_path, main_anim),
			CONNECT_ONE_SHOT
		)
	else:
		_in_transition_slots.erase(slot)
		node.play(first_anim)


func _on_slot_transition_finished(node: AnimatedSprite2D, slot: String, main_path: String, main_anim: String) -> void:
	_in_transition_slots.erase(slot)

	if not ResourceLoader.exists(main_path):
		node.visible = false
		return

	var mf := ResourceLoader.load(main_path) as SpriteFrames
	if mf:
		node.sprite_frames = mf

	if node.sprite_frames and node.sprite_frames.has_animation(main_anim):
		node.play(main_anim)
	else:
		node.visible = false


# =========================
# SYNC FRAME (chamado pelo player._process)
# =========================

func sync_frame(player: Player) -> void:
	if _sync_paused:
		return
	if _equipped_pieces.is_empty():
		return
	if not player.current_armor:
		return
	if player.current_armor.armor_system != ArmorData.ArmorSystem.LAYER:
		return

	var buster: AnimatedSprite2D = player.get_node_or_null("BusterSprite")
	var use_buster := buster != null and buster.visible and buster.sprite_frames

	for slot in _equipped_pieces:
		if _in_transition_slots.get(slot, false):
			continue

		var node: AnimatedSprite2D = player._get_layer_nodes().get(slot)
		if not node or not node.visible or not node.sprite_frames:
			continue

		if use_buster and slot == "arms":
			var buster_count := buster.sprite_frames.get_frame_count(buster.animation)
			var layer_count  := node.sprite_frames.get_frame_count(node.animation)
			if buster_count > 0 and layer_count > 0:
				var ratio := float(buster.frame) / float(buster_count)
				node.frame = int(ratio * layer_count)
		else:
			node.frame = player.sprite.frame

		node.flip_h = player.sprite.flip_h


# =========================
# NOVA STRIKE
# =========================

func can_use_nova_strike() -> bool:
	if not _player or not _player.current_armor:
		return false
	if not _player.current_armor.has_nova_strike:
		return false
	if _nova_strike_used:
		return false
	if _player.current_armor.has_infinite_nova_strike:
		return true
	return _nova_strike_energy >= _get_energy_max()


func on_nova_strike_used() -> void:
	_nova_strike_used = true
	if not _player.current_armor.has_infinite_nova_strike:
		_nova_strike_energy = 0.0


func on_player_landed() -> void:
	_nova_strike_used = false


func on_player_damaged(amount: float) -> void:
	if not _player or not _player.current_armor:
		return
	if _player.current_armor.has_infinite_nova_strike:
		return
	_nova_strike_energy = min(
		_nova_strike_energy + _player.current_armor.nova_strike_damage_refuel,
		_get_energy_max()
	)


func _refuel_nova_strike(delta: float) -> void:
	if not _player or not _player.current_armor:
		return
	if _player.current_armor.has_infinite_nova_strike:
		return
	if not _player.current_armor.has_nova_strike:
		return
	if _nova_strike_energy >= _get_energy_max():
		return
	_nova_strike_energy = min(
		_nova_strike_energy + _player.current_armor.nova_strike_refuel_rate * delta,
		_get_energy_max()
	)


func get_nova_strike_energy_ratio() -> float:
	var max_e = _get_energy_max()
	if max_e <= 0.0:
		return 0.0
	return _nova_strike_energy / max_e


func _get_energy_max() -> float:
	if not _player or not _player.current_armor:
		return 100.0
	return _player.current_armor.nova_strike_energy_max


# =========================
# GETTERS
# =========================

func has_piece(slot: String) -> bool:
	return slot in _equipped_pieces

func get_equipped_pieces() -> Array[String]:
	return _equipped_pieces.duplicate()

func has_any_piece() -> bool:
	return not _equipped_pieces.is_empty()


# =========================
# INTERNO
# =========================

func _apply_armor(path: String) -> void:
	if not _player:
		return
	if not ResourceLoader.exists(path):
		push_warning("❌ Armadura não encontrada: " + path)
		return
	_player.current_armor = load(path)


func _recalculate_capabilities() -> void:
	if not _player or not _player.current_armor:
		return
	if _player.current_armor.armor_system != ArmorData.ArmorSystem.LAYER:
		return

	_player.current_armor.has_air_dash             = false
	_player.current_armor.has_double_jump          = false
	_player.current_armor.can_wall_kick            = false
	_player.current_armor.has_nova_strike          = false
	_player.current_armor.has_infinite_nova_strike = false
	_player.current_armor.has_charge_weapons       = false
	_player.current_armor.has_endless_special      = false
	_player.current_armor.damage_reduction         = 0.0

	for layer in _player.current_armor.armor_layers:
		if layer.slot not in _equipped_pieces:
			continue
		if layer.has_air_dash:             _player.current_armor.has_air_dash = true
		if layer.has_double_jump:          _player.current_armor.has_double_jump = true
		if layer.can_wall_kick:            _player.current_armor.can_wall_kick = true
		if layer.has_nova_strike:          _player.current_armor.has_nova_strike = true
		if layer.has_charge_weapons:       _player.current_armor.has_charge_weapons = true
		if layer.has_endless_special:      _player.current_armor.has_endless_special = true
		if layer.has_infinite_nova_strike: _player.current_armor.has_infinite_nova_strike = true
		_player.current_armor.damage_reduction += layer.damage_reduction

	if _player.current_armor.has_infinite_nova_strike:
		var all_four = ["head", "body", "arms", "legs"].all(
			func(s): return s in _equipped_pieces
		)
		if not all_four:
			_player.current_armor.has_infinite_nova_strike = false


func _can_sync_armor() -> bool:
	if not _player or _equipped_pieces.is_empty():
		return false
	if not _player.current_armor:
		return false
	if _player.current_armor.armor_system != ArmorData.ArmorSystem.LAYER:
		return false
	return true


func _save_to_save() -> void:
	if not SaveSystem.current_save:
		return
	SaveSystem.current_save.x_equipped_pieces = _equipped_pieces.duplicate()
