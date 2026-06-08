# player/states/Hover.gd
extends State

const H_ACCEL:    float = 600.0
const ENERGY_MAX: float = 100.0
const IDLE_DRAIN: float = 50.0
const MOVE_DRAIN: float = 70.0

var _energy:        float = ENERGY_MAX
var _current_level: int   = 0

@export var fx_offset_idle:  Vector2 = Vector2.ZERO
@export var fx_offset_front: Vector2 = Vector2.ZERO
@export var fx_offset_back:  Vector2 = Vector2.ZERO
@export var fx_z_index: int = 0

# Níveis mapeados em hover_state_def.tres → level_animations:
#   0 = "idle"
#   1 = "hoveringback"
#   2 = "hoveringfront"
const FX_NAME := "hover_effect"


func enter() -> void:
	_energy        = ENERGY_MAX
	_current_level = 0
	player.gravity_enabled = false
	player.can_air_dash    = false
	player.visual_library.play_state("Hover")

	var fx := player.fx_component.get_stationary(FX_NAME)
	if fx:
		fx.z_index = fx_z_index
	player.fx_component.start(FX_NAME)
	_apply_level(0)


func update(delta: float) -> void:
	var dir := InputManager.get_move_axis()

	_energy -= (MOVE_DRAIN if abs(dir) > 0.01 else IDLE_DRAIN) * delta
	if _energy <= 0.0 or not InputManager.is_action_pressed("jump"):
		player.gravity_enabled = true
		player.state_machine.change_state("Fall")
		return

	var moving_forward: bool = abs(dir) > 0.01 and (dir > 0.0) == player.facing_right

	if abs(dir) > 0.01:
		player.accelerate_horizontal(dir * 85.0, H_ACCEL, delta)
	else:
		player.accelerate_horizontal(0.0, H_ACCEL, delta)

	player.set_vertical_speed(0.0)

	# Determina nível: 0 = idle, 1 = back, 2 = front
	var level := 0
	if abs(dir) > 0.01:
		level = 2 if moving_forward else 1

	# Só chama set_anim_level quando o nível muda — não toda frame
	if level != _current_level:
		_current_level = level
		_apply_level(level)

	_update_fx(dir, moving_forward)

	if player.is_on_floor():
		player.state_machine.change_state("Land")
		return


func exit() -> void:
	player.gravity_enabled = true
	player.fx_component.stop(FX_NAME)


func _apply_level(level: int) -> void:
	player.visual_library.set_anim_level("Hover", level)


func _update_fx(dir: float, moving_forward: bool) -> void:
	if abs(dir) < 0.01:
		player.fx_component.set_level(FX_NAME, 0, player.facing_right)
		_move_fx_to("HoverIdlePoint", fx_offset_idle)
	elif moving_forward:
		player.fx_component.set_level(FX_NAME, 2, player.facing_right)
		var offset := fx_offset_front
		if not player.facing_right:
			offset.x = -offset.x - 1.5
		_move_fx_to("HoverFrontPoint", offset)
	else:
		player.fx_component.set_level(FX_NAME, 1, player.facing_right)
		_move_fx_to("HoverBackPoint", fx_offset_back)


func _move_fx_to(marker_name: String, offset: Vector2) -> void:
	var marker := player.get_node_or_null(marker_name)
	if marker is Marker2D:
		player.fx_component.set_stationary_position(FX_NAME, (marker as Marker2D).global_position + offset)
