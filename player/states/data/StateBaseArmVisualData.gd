# player/states/data/StateBaseArmVisualData.gd
class_name StateBaseArmVisualData
extends Resource

@export var has_transition: bool = false
@export var transition_file: String = ""   # ex: "spr_x_arm_walk"
@export var transition_anim: String = ""   # ex: "towalk"

@export var main_file: String = ""         # ex: "spr_x_arm_walk"
@export var main_anim: String = ""         # ex: "walkloop"
@export var is_loop: bool = true
