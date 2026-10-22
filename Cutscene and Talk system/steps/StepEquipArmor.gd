# talksystem/steps/StepEquipArmor.gd
class_name StepEquipArmor
extends CutsceneStep

# Equipa uma peça de armadura via ArmorManager
# Só executa se o player for X
@export var slot: String = ""  # "head", "body", "arms", "legs"
