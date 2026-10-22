# talksystem/steps/StepEffects.gd
class_name StepEffects
extends CutsceneStep

## SFX e FX sozinhos, sem animação — ex: explosões depois da animação de derrota.
## Para efeitos JUNTO com uma animação, use o campo "effects" do StepAnimation.

@export var effects: CutsceneEffects
## Quanto o step dura, em segundos. 0 = dispara os efeitos e avança na hora.
## Com sfx_until_end, o som repete enquanto o step durar (precisa de duration > 0).
@export var duration: float = 0.0
