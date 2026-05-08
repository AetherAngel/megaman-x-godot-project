extends Camera2D

@export var follow_speed: float = 13.0
@export var transition_speed: float = 3.5

var target: Node2D = null
var in_transition: bool = false

var _logical_pos: Vector2
var _snapped_target: Vector2

var _was_moving: bool = false
var _last_raw: Vector2
var _initialized: bool = false  # ✅ agora é persistente

func _ready() -> void:
	await get_tree().process_frame
	
	target = get_tree().get_first_node_in_group("player")
	process_priority = 1
	
	if target:
		_logical_pos = target.global_position.round()
		_snapped_target = _logical_pos
		global_position = _logical_pos

func set_transition_mode(enabled: bool) -> void:
	in_transition = enabled

func _stable_snap(value: float, current: float) -> float:
	if abs(value - current) < 0.6:
		return current
	return round(value)

func _physics_process(delta: float) -> void:
	if not target:
		return

	# ✅ roda só UMA vez
	if not _initialized:
		global_position = target.global_position.round()
		_logical_pos = global_position
		_snapped_target = global_position
		_last_raw = target.global_position
		_initialized = true
		return

	var raw = target.global_position
	var is_moving = raw.distance_squared_to(_snapped_target) > 0.01

	# início do movimento
	if is_moving and not _was_moving:
		_snapped_target = raw.round()
		_logical_pos = _snapped_target
		global_position = _snapped_target
		_was_moving = true
		_last_raw = raw
		return

	if not is_moving:
		_was_moving = false
		

	# follow normal
	_snapped_target.x = _stable_snap(raw.x, _snapped_target.x)
	_snapped_target.y = _stable_snap(raw.y, _snapped_target.y)

	var speed = transition_speed if in_transition else follow_speed
	_logical_pos = _logical_pos.lerp(_snapped_target, speed * delta)

	if _logical_pos.distance_squared_to(_snapped_target) < 1.0:
		_logical_pos = _snapped_target

	global_position = _logical_pos.round()

	_last_raw = raw
