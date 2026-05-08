extends State

signal equip_finished      # dispara quando armor_equip começa — dá a peça
signal equip_animation_done # dispara quando armor_equip termina — vai offline

func enter() -> void:
	player.velocity = Vector2.ZERO
	player.can_control = false

	# Esconde todas as layers
	for node in player._get_layer_nodes().values():
		node.visible = false
	
	
	var state_atual = player.state_machine.current_state_name
	print (state_atual)
	if GameManager.current_player == "X":
		_emit_equip_at_frame(4)   # ← dispara em paralelo, não bloqueia
		await player.state_machine.visual_sequence_player.play(player, "Equip")
	else:
		equip_finished.emit()       

	# Força as layers para o frame correto do sprite base
	var layer_nodes = player._get_layer_nodes()
	for node in layer_nodes.values():
		if node.visible:
			node.frame = player.sprite.frame
	

	equip_animation_done.emit()

	player.can_control = true
	GameManager.set_input_mode(GameManager.InputMode.PLAYER)
	InputManager.can_process_player_input = true
	player.state_machine.change_state("Idle")


func exit() -> void:
	ArmorManager.unblock_visual_sync()
	ArmorManager.resume_sync()


func update(_delta: float) -> void:
	player.velocity = Vector2.ZERO


func _emit_equip_at_frame(target_frame: int) -> void:
	while player.sprite.frame < target_frame:
		await player.get_tree().process_frame
	equip_finished.emit()   # equipa a peça no frame certo, enquanto a sequência continua
