# player/states/data/StateArmorVisualData.gd
class_name StateArmorVisualData
extends Resource

# Armor layers (head, body, legs, arms) — normal enquanto não há o buster
@export var main_action: String = "" # ex: "walk"
@export var has_transition: bool = false
@export var transition_file: String = ""        # ex: "spr_x_fourth_{slot}_walk"
@export var transition_anim: String = ""        # ex: "towalk"

@export var main_file: String = ""              # ex: "spr_x_fourth_{slot}_walk"
@export var main_anim: String = ""              # ex: "walkloop"
@export var is_loop: bool = true

# Armor slots (head, body, legs) durante o shoot
@export var armor_shoot_file: String = ""         # ex: "fourth_shoot"
@export var armor_shoot_transition_anim: String = ""
@export var armor_shoot_main_anim: String = ""

# Armor arms durante o buster
@export var buster_has_transition: bool = false
@export var buster_transition_file: String = "" # ex: "spr_x_fourth_arms_walk_shoot"
@export var buster_transition_anim: String = "" # ex: "busterarmstowalk"

@export var buster_file: String = ""            # ex: "spr_x_fourth_arms_walk_shoot"
@export var buster_anim: String = ""            # ex: "busterwalkshoot"
