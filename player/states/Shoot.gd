# player/states/Shoot.gd
extends State

func enter() -> void:
	player.sprite.play(player.current_weapon.shoot_animation)
	_fire_projectile()
	player.get_node("ShootSFX").play()

func update(_delta: float) -> void:
	if not Input.is_action_pressed("shoot"):
		player.state_machine.change_state("Idle")

func _fire_projectile() -> void:
	if player.current_weapon.projectile_scene:
		var proj = player.current_weapon.projectile_scene.instantiate()
		proj.global_position = player.global_position + Vector2(20 if player.facing_right else -20, -8)
		proj.direction = Vector2.RIGHT if player.facing_right else Vector2.LEFT
		get_tree().current_scene.add_child(proj)
