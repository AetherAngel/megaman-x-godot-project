# resources/StageData.gd
class_name StageData
extends Resource

@export var stage_id: String = "chill_penguin"
@export var stage_name: String = "Chill Penguin"
@export var boss_name: String = "Chill Penguin"
@export var icon_path: String = "res://sprites/spr_boss_chill_penguin/icon.png"  # pasta spr_ que você tem
@export var level_scene_path: String = "res://levels/stage_chill_penguin.tscn"
@export var defeated: bool = false  # será sincronizado com SaveSystem
