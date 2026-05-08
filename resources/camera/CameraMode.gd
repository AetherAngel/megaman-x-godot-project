# CameraMode.gd
extends Node
class_name CameraMode

@export var x_axis: bool = true

@onready var camera: Camera2D = get_parent()

func _ready() -> void:
	if camera.has_method("include_mode"):
		camera.include_mode(self)

func get_target() -> Vector2:
	return camera.target.global_position if camera.target else Vector2.ZERO

func activate(_target = null) -> void:
	if x_axis:
		camera.current_mode_x = self
	else:
		camera.current_mode_y = self

func deactivate() -> void:
	if x_axis:
		camera.current_mode_x = null
	else:
		camera.current_mode_y = null

func update(_delta: float) -> Vector2:
	return camera.global_position  # será sobrescrito

func is_executing() -> bool:
	if x_axis:
		return camera.current_mode_x == self
	return camera.current_mode_y == self
