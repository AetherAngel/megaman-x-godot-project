# player/states/data/StateDefinition.gd
class_name StateDefinition
extends Resource

@export var state_name: String = ""
@export var state_script: GDScript          # arrasta o .gd do state aqui
@export var has_transition: bool = false
@export var visual_data: StateVisualData
