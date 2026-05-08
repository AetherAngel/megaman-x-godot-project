extends Parallax2D

func _physics_process(_delta: float) -> void:
	position = position.round()
