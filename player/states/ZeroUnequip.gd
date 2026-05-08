extends State

func enter() -> void:
	# Pega o unequip_animation do último AttackData usado
	var unequip_anim := "zero_unequip"  # fallback
	var skill_tree = player.current_character.skill_tree if player.current_character else null

	if skill_tree:
		var last_data := skill_tree.get_attack_data(player.combo_count)
		if last_data and not last_data.unequip_animation.is_empty():
			unequip_anim = last_data.unequip_animation

	# Carrega o set correto baseado no último ataque
	var set_to_load := "atk_1"
	if skill_tree:
		var last_data := skill_tree.get_attack_data(player.combo_count)
		if last_data and not last_data.set_name.is_empty():
			set_to_load = last_data.set_name

	player.change_animation_set(set_to_load)

	if player.sprite.sprite_frames.has_animation(unequip_anim):
		player.sprite.play(unequip_anim)
		print("▶️ SaberUnequip: ", unequip_anim)
	else:
		print("⚠️ Animação '%s' não encontrada" % unequip_anim)
		player.state_machine.change_state("Idle")
		return

	player.combo_count = 1

func update(_delta: float) -> void:
	player.damp_horizontal(0.85)
	if not player.sprite.is_playing():
		player.state_machine.change_state("Idle")
