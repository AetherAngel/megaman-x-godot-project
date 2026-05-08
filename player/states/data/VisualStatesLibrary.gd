extends Resource
class_name VisualStateLibrary

@export var states: Array[StateVisualData] = []

func get_state_data(state_name: String) -> StateVisualData:
	for state in states:
		if state.state_name.to_lower() == state_name.to_lower():
			return state
	return null
