# talksystem/steps/StepAnimation.gd
class_name StepAnimation
extends CutsceneStep

@export var target_group: String = ""    # grupo do nó a animar ex: "light_capsule"
@export var animation: String = ""       # nome da animação a tocar
@export var wait_to_finish: bool = true  # espera terminar antes de ir pro próximo step
