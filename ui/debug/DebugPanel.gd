extends Control

# ─── Estados ─────────────────────────────────────────────────
enum State { IDLE, POPUP_OPEN, PLACING }
var _state: int = State.IDLE

var flipcalled: bool = false
var _pending_entry
var _active_category: String = "enemy"
var _previous_input_mode: GameManager.InputMode = GameManager.InputMode.PLAYER

# ─── Nós ─────────────────────────────────────────────────────
@onready var sidebar:      PanelContainer = $Sidebar
@onready var grid:         GridContainer  = $Sidebar/Margin/VBox/Scroll/Grid
@onready var feedback_lbl: Label          = $Sidebar/Margin/VBox/FeedbackLabel

@onready var spawn_popup:  Control        = $SpawnPopup
@onready var entry_list:   VBoxContainer  = $SpawnPopup/Panel/VBox/Scroll/EntryList
@onready var btn_enemies:  Button         = $SpawnPopup/Panel/VBox/CategoryBar/BtnEnemies
@onready var btn_items:    Button         = $SpawnPopup/Panel/VBox/CategoryBar/BtnItems
@onready var btn_cancelar: Button         = $SpawnPopup/Panel/VBox/BtnCancelar

@onready var placing_hint: Label          = $PlacingHint


# ─── Ready ───────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("debug_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	sidebar.add_theme_stylebox_override("panel", style)
	sidebar.clip_contents = true

	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)

	_validate_nodes()

	if btn_enemies:  btn_enemies.pressed.connect(func(): _set_category("enemy"))
	if btn_items:    btn_items.pressed.connect(func(): _set_category("item"))
	if btn_cancelar: btn_cancelar.pressed.connect(_close_popup)


func _validate_nodes() -> void:
	var checks := {
		"grid":         grid,
		"feedback_lbl": feedback_lbl,
		"spawn_popup":  spawn_popup,
		"entry_list":   entry_list,
		"placing_hint": placing_hint,
	}
	for key in checks:
		if checks[key] == null:
			push_error("[DebugPanel] NÓ NULO: %s" % key)


func _fit_to_viewport() -> void:
	set_position(Vector2.ZERO)
	set_size(get_viewport().get_visible_rect().size)


# ─── Toggle ──────────────────────────────────────────────────
func toggle(active: bool) -> void:
	visible = active

	if active:
		_previous_input_mode = GameManager.current_input_mode
		get_tree().paused = true
		GameManager.set_input_mode(GameManager.InputMode.MENU)
		call_deferred("_build_sidebar_buttons")
	else:
		_cancel_placing()
		_close_popup()
		get_tree().paused = false
		GameManager.set_input_mode(_previous_input_mode)
		_state = State.IDLE


# ─── Sidebar ─────────────────────────────────────────────────
func _build_sidebar_buttons() -> void:
	if not grid:
		push_error("[DebugPanel] grid é null!")
		return

	for c in grid.get_children():
		c.free()

	# Usa CharacterManagement como fonte de verdade do personagem ativo.
	var active_data := CharacterManagement.get_active_data()
	var is_x := active_data != null and active_data.character_id == &"X"

	for slot in ["head", "body", "arms", "legs"]:
		_add_btn(
			slot.to_upper(),
			_on_equip_slot.bind(slot),
			not is_x
		)

	_add_btn("SPAWN",        _open_popup)
	
	_add_btn("MAGMA DRAGON", _on_next_map)
	_add_btn("RESET LAYERS", _on_reset_layers)
	
	_add_separator()
	_add_btn("Flip Boss Facing", _flip_boss)

	_add_separator()
	_add_btn("SAVE",         _on_save)
	_add_btn("RESET SAVE",   _on_reset_save, false, Color(0.8, 0.2, 0.2))

	_add_separator()
	_add_btn("CHANGEPLAYER", _switch_current_player)
	_add_btn("ToCheckpoint", _tocheckpoint_)
	_add_btn("EXIT",         _on_exit_debug)


func _add_btn(label: String, callable: Callable, disabled := false, color: Color = Color.WHITE) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 22)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 9)
	btn.disabled = disabled
	if color != Color.WHITE:
		btn.add_theme_color_override("font_color", color)
	btn.pressed.connect(callable)
	grid.add_child(btn)


func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 4)
	grid.add_child(sep)


# ─── SpawnPopup ──────────────────────────────────────────────
func _open_popup() -> void:
	_state = State.POPUP_OPEN
	spawn_popup.visible = true
	_set_category("enemy")


func _close_popup() -> void:
	spawn_popup.visible = false
	if _state == State.POPUP_OPEN:
		_state = State.IDLE


func _set_category(category: String) -> void:
	_active_category = category
	btn_enemies.button_pressed = (category == "enemy")
	btn_items.button_pressed   = (category == "item")
	_populate_entry_list()


func _populate_entry_list() -> void:
	for c in entry_list.get_children():
		c.queue_free()

	if not get_node_or_null("/root/SpawnCatalog"):
		var lbl := Label.new()
		lbl.text = "(SpawnCatalog não registrado)"
		entry_list.add_child(lbl)
		return

	var catalog = get_node("/root/SpawnCatalog")
	var entries: Array = catalog.get_by_category(_active_category)

	if entries.is_empty():
		var lbl := Label.new()
		lbl.text = "(nenhum cadastrado)"
		entry_list.add_child(lbl)
		return

	for entry in entries:
		var btn := Button.new()
		btn.text = entry.label
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 20)
		btn.add_theme_font_size_override("font_size", 9)
		btn.pressed.connect(_on_entry_selected.bind(entry))
		entry_list.add_child(btn)


func _on_entry_selected(entry) -> void:
	_pending_entry = entry
	_close_popup()
	_start_placing()


# ─── Modo "clique no mapa" ────────────────────────────────────
func _start_placing() -> void:
	_state = State.PLACING
	sidebar.visible = false
	placing_hint.visible = true
	placing_hint.text = "Spawnar: %s  |  LMB confirma  |  RMB cancela" % _pending_entry.label
	get_tree().paused = false


func _cancel_placing() -> void:
	if _state != State.PLACING:
		return
	_pending_entry = null
	_state = State.IDLE
	sidebar.visible = true
	placing_hint.visible = false
	get_tree().paused = true
	_feedback("Spawn cancelado.")


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.PLACING:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_do_spawn(get_viewport().get_canvas_transform().affine_inverse() * event.position)
			MOUSE_BUTTON_RIGHT:
				_cancel_placing()
		get_viewport().set_input_as_handled()


func _do_spawn(world_pos: Vector2) -> void:
	var catalog = get_node("/root/SpawnCatalog")
	var node = catalog.instantiate(_pending_entry)
	if not node:
		_feedback("Falha ao instanciar!")
		_cancel_placing()
		return

	var player = get_tree().get_first_node_in_group("player")
	var parent: Node = player.get_parent() if player else get_tree().current_scene

	if node is Node2D:
		node.global_position = world_pos

	parent.add_child(node)
	_feedback("%s spawnado!" % _pending_entry.label)

	_pending_entry = null
	_state = State.IDLE
	sidebar.visible = true
	placing_hint.visible = false
	get_tree().paused = true


# ─── Layer equip / reset ─────────────────────────────────────
func _on_equip_slot(slot: String) -> void:
	var active_data := CharacterManagement.get_active_data()
	if active_data == null or active_data.character_id != &"X":
		_feedback("Apenas X pode usar armaduras!")
		return

	if ArmorManager.has_piece(slot):
		ArmorManager.unequip_piece(slot)
		_feedback("%s removida!" % slot.to_upper())
	else:
		ArmorManager.equip_piece(slot)
		_feedback("%s equipada!" % slot.to_upper())


func _on_next_map() -> void:
	get_tree().paused = false
	GameManager.set_input_mode(_previous_input_mode)
	# Pelo start_stage: define current_stage_id e toca a música da fase (MD).
	GameManager.start_stage(load("res://levels/stage_data/stage_magma_dragon.tres") as StageData)
	


func _on_reset_layers() -> void:
	var active_data := CharacterManagement.get_active_data()
	if active_data == null or active_data.character_id != &"X":
		_feedback("Apenas X pode resetar armaduras!")
		return

	for slot in ["head", "body", "arms", "legs"]:
		ArmorManager.unequip_piece(slot)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.apply_armor()
		player.change_animation_set("idle")

	_feedback("Reset OK!")


# ─── Save ────────────────────────────────────────────────────
func _on_save() -> void:
	SaveSystem.collect_game_data()
	SaveSystem.save()
	_feedback("✅ Save realizado!")

	# TODO: save via tela dedicada no menu de pause (futuro).


func _on_reset_save() -> void:
	SaveSystem.reset_save()
	_feedback("🗑️ Save resetado! Reinicie para aplicar.")

	# TODO: recarregar cena automaticamente após reset (futuro).


# ─── Exit ────────────────────────────────────────────────────
func _on_exit_debug() -> void:
	InputManager.can_process_player_input = true
	toggle(false)


# ─── Switch Player ───────────────────────────────────────────
func _switch_current_player() -> void:
	# CharacterManagement.cycle_next() cicla pelo roster registrado no editor.
	# Adicionar novo personagem = arrastar .tres no Autoload inspector.
	# Zero código novo aqui.
	CharacterManagement.cycle_next()

	print("🔄 Debug Switch: personagem ativo → %s" % CharacterManagement.get_active_id())

	get_tree().paused = false
	GameManager.set_input_mode(_previous_input_mode)
	visible = false
	_state = State.IDLE

	# Player reage via CharacterManagement.character_switched signal.
	# Não é necessário chamar player_node.on_character_changed() diretamente.


# ─── Checkpoint ──────────────────────────────────────────────
func _tocheckpoint_() -> void:
	if GameManager.active_checkpoint == null:
		print("⚠️ Nenhum checkpoint ativado ainda.")
		return

	var player_node: Player = get_tree().get_first_node_in_group("player") as Player
	if not player_node:
		push_error("[DebugPanel] Player não encontrado para teleporte ao checkpoint.")
		return

	# reinitialize() re-executa o setup do personagem atual sem trocar de personagem.
	player_node.visual_library.reinitialize_for_current_player(player_node)
	player_node.reinitialize()
	GameManager.active_checkpoint.debug_trigger(player_node)


# ─── Feedback ────────────────────────────────────────────────
func _feedback(msg: String) -> void:
	feedback_lbl.text = msg
	print("[DEBUG] " + msg)

# ─── Boss specific tests ─────────────────────────────────────
func _flip_boss() -> void:
	flipcalled = !flipcalled
	GameManager.current_boss.debug_force_facing(flipcalled)
	print("Debug Panel: Forçando Boss a virar de direção via (debug_force_facing) = ", flipcalled)
