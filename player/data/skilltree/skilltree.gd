extends Resource
class_name SkillTree

@export var character_name: String = "Zero"
@export var basic_combo: Array[AttackData] = []
@export var ultimate_attack: AttackData
@export var can_charge_shot: bool = false

# Retorna AttackData pelo índice do combo (1-based)
func get_attack_data(combo_index: int) -> AttackData:
	if basic_combo.is_empty():
		return null
	var idx := clampi(combo_index - 1, 0, basic_combo.size() - 1)
	return basic_combo[idx]

# Retorna o nome do próximo State
func get_next_combo_state(current_combo: int) -> String:
	var data := get_attack_data(current_combo)
	if not data or data.is_final_combo or data.next_combo_state.is_empty():
		return "SaberUnequip"
	return data.next_combo_state
