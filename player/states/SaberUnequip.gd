extends State

func enter() -> void:
	# SaberUnequip é exclusivo de personagens com saber
	if player.current_character.default_weapon != "saber":
		player.combo_count = 0
		player.set_meta("came_from_attack", false)
		player.state_machine.change_state("Idle")
		return

	InputManager.consume_shoot_buffer()
	
	
	# Pega o unequip do último AttackData usado
	var unequip_anim := ""
	if player.current_character and player.current_character.skill_tree:
		var last_data := player.current_character.skill_tree.get_attack_data(player.combo_count)
		if last_data and not last_data.unequip_animation.is_empty():
			unequip_anim = last_data.unequip_animation
			player.change_animation_set(last_data.set_name)

	player.combo_count = 0
	player.set_meta("came_from_attack", false)

	if unequip_anim.is_empty() or not player.sprite.sprite_frames.has_animation(unequip_anim):
		print("⚠️ Animação unequip não encontrada, voltando pro Idle")
		player.state_machine.change_state("Idle")
		return

	player.sprite.play(unequip_anim)
	print("⚔️ Iniciando animação de unequip: %s" % unequip_anim)

func update(_delta: float) -> void:
	player.damp_horizontal(0.85)

	# Se apertar ataque durante unequip, reinicia o combo
	if InputManager.consume_shoot_buffer():
		if player.current_character.default_weapon == "saber":
			player.combo_count = 1
			player.state_machine.change_state("SaberAttack")
			return

	if not player.sprite.is_playing():
		player.state_machine.change_state("Idle")
