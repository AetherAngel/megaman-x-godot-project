# player/states/StateBase.gd
extends Node
class_name State

var cancel_used := false
var combo_consumed := false
var player: Player

func enter() -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass


# =========================
# TECHNIQUE CHECKER
# =========================
func _check_techniques(techniques: Array[InputTechnique]) -> bool:
	for tech in techniques:
		if not InputManager.is_action_just_pressed(tech.action):
			continue
		if not _matches_modifiers(tech):
			continue
		if not tech.requires_flag.is_empty():
			if player.get(tech.requires_flag) != tech.flag_value:
				continue
		player.state_machine.change_state(tech.target_state)
		return true
	return false


func _matches_modifiers(tech: InputTechnique) -> bool:
	if tech.modifiers.is_empty():
		return true
	if tech.any_modifier:
		for mod in tech.modifiers:
			if InputManager.is_action_pressed(mod):
				return true
		return false
	# AND — todos precisam estar pressionados
	for mod in tech.modifiers:
		if not InputManager.is_action_pressed(mod):
			return false
	return true
