# autoload/InputManager.gd
extends Node

var bindings = {
	"move_left":      ["move_left"],
	"move_right":     ["move_right"],
	"move_up":        ["move_up"],
	"move_down":      ["move_down"],
	"jump":           ["jump"],
	"shoot":          ["shoot"],
	"special_weapon": ["special_weapon"],
	"dash":           ["dash"],
	"debug_mode":     ["debug_mode"]
}

var shoot_buffer: float = 0.0
var shoot_buffer_time: float = 0.5

var jump_buffer: float = 0.0
var jump_buffer_time: float = 0.1

var can_process_player_input: bool = false

# === DEBUG SESSION BLOCK START ===
var debug_mode_active: bool = false
# === DEBUG SESSION BLOCK END ===

func _ready() -> void:
	GameManager.input_mode_changed.connect(_on_input_mode_changed)

func _process(delta: float) -> void:
	# === DEBUG SESSION BLOCK START ===
	if Input.is_action_just_pressed("debug_mode"):
		debug_mode_active = !debug_mode_active
		var panel = get_tree().get_first_node_in_group("debug_panel")
		if panel:
			panel.toggle(debug_mode_active)
	# === DEBUG SESSION BLOCK END ===

	if shoot_buffer > 0.0:
		shoot_buffer -= delta
	if jump_buffer > 0.0:
		jump_buffer -= delta

	if can_process_player_input and GameManager.current_input_mode == GameManager.InputMode.PLAYER:
		if _is_shoot_just_pressed_raw() and shoot_buffer <= 0.0:
			register_shoot_buffer()
			print("🔥 SHOOT BUFFER REGISTERED (Player Liberado)")
		if _is_jump_just_pressed_raw() and jump_buffer <= 0.0:
			register_jump_buffer()
	else:
		if shoot_buffer > 0.0:
			shoot_buffer = 0.0
		if jump_buffer > 0.0:
			jump_buffer = 0.0


# ==================== FUNÇÕES PÚBLICAS ====================

func is_action_pressed(action: String) -> bool:
	if not can_process_player_input or GameManager.current_input_mode != GameManager.InputMode.PLAYER:
		return false
	for mapped in bindings.get(action, []):
		if Input.is_action_pressed(mapped):
			return true
	return false

func is_action_just_pressed(action: String) -> bool:
	if not can_process_player_input or GameManager.current_input_mode != GameManager.InputMode.PLAYER:
		return false
	for mapped in bindings.get(action, []):
		if Input.is_action_just_pressed(mapped):
			return true
	return false

func is_action_just_released(action: String) -> bool:
	if GameManager.current_input_mode != GameManager.InputMode.PLAYER:
		return false
	for mapped in bindings.get(action, []):
		if Input.is_action_just_released(mapped):
			return true
	return false

func get_move_axis() -> float:
	if GameManager.current_input_mode != GameManager.InputMode.PLAYER:
		return 0.0
	var left = is_action_pressed("move_left")
	var right = is_action_pressed("move_right")
	if left and not right: return -1.0
	if right and not left: return 1.0
	return 0.0


# ==================== BUFFER ====================

func register_shoot_buffer() -> void:
	if shoot_buffer > 0.0:
		return
	shoot_buffer = shoot_buffer_time

func has_shoot_buffer() -> bool:
	return shoot_buffer > 0.0

func consume_shoot_buffer() -> bool:
	if shoot_buffer > 0.0:
		shoot_buffer = 0.0
		return true
	return false

func register_jump_buffer() -> void:
	if jump_buffer > 0.0:
		return
	jump_buffer = jump_buffer_time

func has_jump_buffer() -> bool:
	return jump_buffer > 0.0

func consume_jump_buffer() -> bool:
	if jump_buffer > 0.0:
		jump_buffer = 0.0
		return true
	return false


# ==================== FUNÇÕES INTERNAS ====================

func _is_shoot_just_pressed_raw() -> bool:
	for mapped in bindings.get("shoot", []):
		if Input.is_action_just_pressed(mapped):
			return true
	return false

func _is_jump_just_pressed_raw() -> bool:
	for mapped in bindings.get("jump", []):
		if Input.is_action_just_pressed(mapped):
			return true
	return false

func _on_input_mode_changed(new_mode: GameManager.InputMode) -> void:
	if new_mode != GameManager.InputMode.PLAYER:
		shoot_buffer = 0.0
		jump_buffer = 0.0
		can_process_player_input = false
		print("🧹 BUFFER LIMPO INSTANTÂNEO via sinal (mudou pra MENU)")
