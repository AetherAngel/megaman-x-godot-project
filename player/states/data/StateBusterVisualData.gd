# player/states/data/StateBusterVisualData.gd
class_name StateBusterVisualData
extends Resource

@export var has_transition: bool = false
@export var transition_file: String = ""   # ex: "spr_x_buster_walk"
@export var transition_anim: String = ""   # ex: "bustertowalk"

@export var main_file: String = ""         # ex: "spr_x_buster_walk"
@export var main_anim: String = ""         # ex: "walkshoot"
@export var is_loop: bool = false 
