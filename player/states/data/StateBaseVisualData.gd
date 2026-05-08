# player/states/data/StateBaseVisualData.gd
class_name StateBaseVisualData
extends Resource

@export var has_transition: bool = false
@export var transition_file: String = ""   # ex: "spr_x_walk"
@export var transition_anim: String = ""   # ex: "towalk"

@export var main_file: String = ""         # ex: "spr_x_walk"
@export var main_anim: String = ""         # ex: "walkloop"
@export var is_loop: bool = true

@export var shoot_file: String = ""        # ex: "spr_x_walk_shoot"
@export var shoot_transition_anim: String = "" # ex "towalk"
@export var shoot_main_anim: String = ""        # ex: "walkshoot"
