extends Camera2D
class_name StablePixelCamera

var target: Node2D

func _ready() -> void:
	process_priority = 999
	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if not target:
		return

	global_position = target.global_position
	global_position = global_position.round()
