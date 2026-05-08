class_name InputTechnique extends Resource

@export var action: String = "shoot"
# modifiers com any_modifier = false → todos precisam estar pressionados (AND)
# modifiers com any_modifier = true  → qualquer um basta (OR) — ex: Raikousen
@export var modifiers: Array[String] = []
@export var any_modifier: bool = false
# flag opcional do player — ex: "can_double_jump" = false para Mikazukizan
@export var requires_flag: String = ""
@export var flag_value: bool = true
@export var target_state: String = ""
