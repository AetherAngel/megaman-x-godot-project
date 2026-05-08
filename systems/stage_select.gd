# stage_select.gd
extends Control

const ROWS = 2
const COLS = 4
const DOUBLE_PRESS_TIME = 0.25

@onready var background: TextureRect = $Background
@onready var top_row: HBoxContainer = $GridContainer/TopRow
@onready var bottom_row: HBoxContainer = $GridContainer/BottomRow
@onready var center_top_info: Control = $GridContainer/CenterTopInfo
@onready var center_bottom_sigma: Control = $GridContainer/CenterBottomSigma
@onready var cursor: TextureRect = $Cursor

var slots: Array[Control] = []           # 0-3 top | 4 = center_top_info | 5-8 bottom | 9 = center_bottom_sigma
var cursor_grid_pos: Vector2i = Vector2i(0, 0)  # (coluna 0-3, linha 0=top, 1=bottom)
var is_on_sigma_slot: bool = false

var stages: Array[StageData] = []        # só os 8 normais
var sigma_unlocked: bool = false

var last_dir: Vector2i = Vector2i.ZERO
var last_press_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_background()
	_load_stages()
	_build_grid()
	_update_cursor()
	GameManager.state_changed.connect(_on_state_changed)
	
	# Sigma começa bloqueado (só abre depois de 8 bosses)
	sigma_unlocked = _check_all_bosses_defeated()

func _load_background() -> void:
	background.texture = load("res://sprites/spr_stage_select_background/background.png")  # ajuste se o nome exato for diferente

func _load_stages() -> void:
	stages = [
		_create_stage("chill_penguin", "Chill Penguin", "res://sprites/spr_boss_chill_penguin/", "res://levels/stage_chill_penguin.tscn"),
		_create_stage("spark_mandrill", "Spark Mandrill", "res://sprites/spr_boss_spark_mandrill/", "res://levels/stage_spark_mandrill.tscn"),
		# Adicione aqui os outros 6 bosses usando as pastas spr_boss_xxx do Essentials.rar
		# Ex: _create_stage("armored_armadillo", "Armored Armadillo", "res://sprites/spr_boss_armored_armadillo/", "..."),
	]

func _create_stage(id: String, name: String, icon_folder: String, level_path: String) -> StageData:
	var data = StageData.new()
	data.stage_id = id
	data.stage_name = name
	data.level_scene_path = level_path
	var dir = DirAccess.open(icon_folder)
	if dir:
		for f in dir.get_files():
			if f.ends_with(".png"):
				data.icon_path = icon_folder + f
				break
	return data

func _build_grid() -> void:
	# Popula 8 slots normais
	slots.clear()
	for child in top_row.get_children() + bottom_row.get_children():
		if child is Control:
			slots.append(child)
	
	# Center top = INFO (não selecionável, só display)
	center_top_info.get_node("Label").text = "STAGE SELECT"  # ou nome do boss selecionado
	# Center bottom = SIGMA
	center_bottom_sigma.get_node("TextureButton").disabled = not sigma_unlocked
	center_bottom_sigma.get_node("Label").text = "SIGMA FORTRESS"

func _input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.STAGE_SELECT: return
	
	var dir = Vector2i.ZERO
	if event.is_action_pressed("ui_left"): dir = Vector2i(-1, 0)
	elif event.is_action_pressed("ui_right"): dir = Vector2i(1, 0)
	elif event.is_action_pressed("ui_up"): dir = Vector2i(0, -1)
	elif event.is_action_pressed("ui_down"): dir = Vector2i(0, 1)
	if dir == Vector2i.ZERO: return

	var now = Time.get_ticks_msec() / 1000.0
	var double_press = (dir == last_dir and now - last_press_time < DOUBLE_PRESS_TIME)
	last_dir = dir
	last_press_time = now

	# === MOVIMENTO NA GRID 2x4 + CENTRAIS ===
	if is_on_sigma_slot:
		if dir.y == -1:  # up do sigma volta pra bottom row centro
			is_on_sigma_slot = false
			cursor_grid_pos = Vector2i(1, 1)  # meio da bottom row
		return

	# Movimento normal
	cursor_grid_pos.x = clamp(cursor_grid_pos.x + dir.x, 0, COLS-1)
	cursor_grid_pos.y = clamp(cursor_grid_pos.y + dir.y, 0, ROWS-1)

	# Double-press wrap (exatamente como você pediu)
	if double_press:
		if dir.x == -1 and cursor_grid_pos.x == 0:
			_go_to_shop_menu(); return
		if dir.x == 1 and cursor_grid_pos.x == COLS-1:
			_go_to_equip_menu(); return
		if dir.y == 1 and cursor_grid_pos.y == ROWS-1:
			_go_to_save_menu(); return

	# Se estiver na coluna do meio (coluna 1 ou 2) e apertar up/down → vai para os slots centrais
	if cursor_grid_pos.x == 1 or cursor_grid_pos.x == 2:
		if dir.y == -1 and cursor_grid_pos.y == 0:  # up no topo → info (não selecionável)
			center_top_info.grab_focus()
		if dir.y == 1 and cursor_grid_pos.y == 1:   # down no fundo → sigma
			if sigma_unlocked:
				is_on_sigma_slot = true
				_select_sigma_stage()
			else:
				# feedback "locked"
				pass

	_update_cursor()

func _update_cursor() -> void:
	var index = cursor_grid_pos.y * COLS + cursor_grid_pos.x
	for i in slots.size():
		slots[i].get_node("TextureButton").modulate = Color.WHITE if i == index else Color(0.6, 0.6, 0.6)
	
	cursor.position = slots[index].global_position + Vector2(32, 32)  # ajuste offset do cursor

func _check_all_bosses_defeated() -> bool:
	if not SaveSystem.current_save: return false
	return stages.all(func(s): return SaveSystem.current_save.defeated_bosses.get(s.stage_id, false))

func _select_stage(index: int) -> void:
	var selected = stages[index]
	GameManager.start_stage(selected.stage_id)

func _select_sigma_stage() -> void:
	# TODO: criar stage sigma fortress (várias fases)
	GameManager.start_stage("sigma_fortress")

# Menus laterais via double-press
func _go_to_shop_menu():  GameManager.change_state(GameManager.GameState.SHOP)
func _go_to_equip_menu(): GameManager.change_state(GameManager.GameState.EQUIP)
func _go_to_save_menu():  GameManager.change_state(GameManager.GameState.SAVE_MENU)

func _on_state_changed(new_state):
	visible = (new_state == GameManager.GameState.STAGE_SELECT)
