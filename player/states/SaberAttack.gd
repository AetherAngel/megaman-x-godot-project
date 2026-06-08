extends State

var can_cancel := false
var decision_locked := false
var hold_elapsed := 0.0
var current_combo: int = 1
var current_attack_data: AttackData

func enter() -> void:
	if has_method("is_on_floor"):
		return
	if GameManager.current_player != "Zero":
		player.combo_count = 0
		player.state_machine.change_state("Idle")
		return
		
	if not player.current_character or not player.current_character.skill_tree:
		push_error("❌ SkillTree está NULL!")
		#player.state_machine.change_state("SaberUnequip")
		return

	decision_locked = false
	hold_elapsed = 0.0
	can_cancel = false

	current_combo = player.combo_count
	current_attack_data = player.current_character.skill_tree.get_attack_data(current_combo)

	if not current_attack_data:
		push_warning("❌ AttackData nulo para combo %d" % current_combo)
		player.state_machine.change_state("SaberUnequip")
		return

	player.change_animation_set(current_attack_data.set_name)
	player.set_meta("came_from_attack", true)

	var anim := current_attack_data.animation_name
	if player.sprite.sprite_frames and player.sprite.sprite_frames.has_animation(anim):
		player.sprite.play(anim)
		print("▶️ [combo %d] set=%s  anim=%s" % [current_combo, current_attack_data.set_name, anim])
		# Toca o som do ataque
		if not current_attack_data.sfx_name.is_empty():
			SoundManager.play_sfx(current_attack_data.sfx_name, current_attack_data.sfx_volume, current_attack_data.sfx_pitch)
			print("▶️ tocando som SFX")
	else:
		push_warning("⚠️ Animação '%s' não encontrada em '%s'" % [anim, current_attack_data.set_name])
		print("   Animações disponíveis: ", player.sprite.sprite_frames.get_animation_names())
		player.state_machine.change_state("SaberUnequip")
		return

	InputManager.consume_shoot_buffer()

func update(delta: float) -> void:
	if decision_locked:
		return

	hold_elapsed += delta
	player.stop_all_movement()

	if not can_cancel and hold_elapsed >= current_attack_data.cancel_start:
		can_cancel = true
		InputManager.consume_shoot_buffer()
		print("🟡 [combo %d] can_cancel ATIVO" % current_combo)

	if can_cancel and InputManager.consume_shoot_buffer():
		decision_locked = true
		var next_state := player.current_character.skill_tree.get_next_combo_state(current_combo)
		if next_state == "SaberUnequip":
			player.combo_count = 1
			print("🔥 [combo %d] → SaberUnequip" % current_combo)
			player.state_machine.change_state("SaberUnequip")
		else:
			player.combo_count += 1
			print("🔥 [combo %d] → próximo ataque" % current_combo)
			enter()
		return

	if current_attack_data.is_final_combo:
		if not player.sprite.is_playing():
			decision_locked = true
			player.combo_count = 1
			print("💀 [combo %d] animação finalizada → SaberUnequip" % current_combo)
			player.state_machine.change_state("SaberUnequip")
	else:
		if not player.sprite.is_playing() or hold_elapsed >= current_attack_data.hold_duration:
			decision_locked = true
			player.combo_count = 1
			print("💀 [combo %d] → SaberUnequip (timeout)" % current_combo)
			player.state_machine.change_state("SaberUnequip")

func exit() -> void:
	decision_locked = true
