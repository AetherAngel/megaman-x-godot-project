extends State

func enter() -> void:
	player.sprite.play("hurt")

	# Knockback: usa helper do Actor, não toca velocity diretamente.
	var knockback_dir := -1 if player.facing_right else 1
	player.set_horizontal_speed(player.speed * 2.0 * knockback_dir)

	# Deixa a gravidade do Actor trabalhar normalmente.
	# NÃO aplicar gravity manualmente aqui — Actor já faz isso em _apply_gravity.
	# NÃO chamar move_and_slide aqui — Actor faz isso em _process_movement,
	# o que garante que o pixel snap do Character também rode.

	await get_tree().create_timer(0.6).timeout
	player.state_machine.change_state("Idle")


func update(_delta: float) -> void:
	# Movimento e gravidade são totalmente gerenciados pela cadeia do Actor.
	# Este state não precisa fazer nada além de aguardar o timer do enter().
	pass
