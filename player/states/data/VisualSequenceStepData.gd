extends Resource
class_name VisualSequenceStepData

@export var base_visual: StateBaseVisualData
@export var base_arm_visual: StateBaseArmVisualData
@export var buster_visual: StateBusterVisualData
@export var armor_visual: StateArmorVisualData

@export var wait_for_completion: bool = true
@export var wait_until_on_floor: bool = false
@export var custom_delay: float = 0.0
