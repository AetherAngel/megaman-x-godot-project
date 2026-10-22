# talksystem/steps/StepFade.gd
class_name StepFade
extends CutsceneStep

## Escurece ou clareia a tela inteira via ScreenFade.

enum Mode { FADE_OUT, FADE_IN }

## FADE_OUT = tela escurece. FADE_IN = tela volta ao normal.
@export var mode: Mode = Mode.FADE_OUT
## Duração do fade em segundos. 0 = instantâneo.
@export var duration: float = 0.5
## Espera o fade terminar antes de ir pro próximo step.
@export var wait_to_finish: bool = true
