# player/states/ZeroLand.gd
extends State

func enter() -> void:
	player.change_animation_set("atk_land")
	if player.sprite.sprite_frames.has_animation("atk_land"):
		player.sprite.play("atk_land")
	else:
		player.state_machine.change_state("Idle")

func update(_delta: float) -> void:
	player.velocity.x *= 0.85
	if not player.sprite.is_playing():
		player.state_machine.change_state("Idle")
