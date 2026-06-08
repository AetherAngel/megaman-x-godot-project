extends State

var _has_finished := false

func enter() -> void:
	_has_finished = false   # ← reseta sempre que entra
	player.can_control = false
	player.velocity = Vector2.ZERO
	await player.state_machine.visual_sequence_player.play(player, "Intro")
	if not _has_finished:
		_finish_intro()

func _finish_intro() -> void:
	if _has_finished:
		return
	_has_finished = true
	player.can_control = true
	GameManager.set_input_mode(GameManager.InputMode.PLAYER)
	InputManager.can_process_player_input = true
	player.state_machine.change_state("Equip")
	
func exit() -> void:
	player.can_control = true
