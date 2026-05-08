# player/states/data/VisualPlaybackData.gd
class_name VisualPlaybackData
extends RefCounted

# Arquivo .tres a carregar
var frames_path: String = ""
var frames: SpriteFrames = null

# Animação de transição (opcional)
var has_transition: bool = false
var transition_anim: String = ""

# Animação principal
var main_anim: String = ""
var is_loop: bool = true


func is_valid() -> bool:
	return frames != null and not main_anim.is_empty()
