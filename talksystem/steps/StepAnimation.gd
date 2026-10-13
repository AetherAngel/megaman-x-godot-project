# talksystem/steps/StepAnimation.gd
class_name StepAnimation
extends CutsceneStep

@export var target_group: String = ""    # grupo do nó a animar ex: "light_capsule"
@export var animation: String = ""       # nome da animação a tocar
@export var wait_to_finish: bool = true  # espera terminar antes de ir pro próximo step

## Timer chefe do Step, em segundos. 0 = desligado (comportamento de sempre).
## wait_to_finish MARCADO   → espera o fim natural; este valor é só um teto
##                            de segurança (se o fim natural nunca vier, corta).
## wait_to_finish DESMARCADO → o Step segura o Sequencer exatamente este
##                            tempo antes de avançar.
## Ao vencer, para o movimento físico que ESTE step iniciou (se houver) —
## nunca mexe em timers/animações de outro sistema ou de outro step.
@export var step_total_duration: float = 0.0

@export_group("Movimento físico (opcional)")
## Se preenchido, roda essa movimentação JUNTO com a animação acima —
## no mesmo Step, sem precisar de um StepPhysicalMove separado na
## sequência. Com ele presente, o "fim natural" que wait_to_finish espera
## é o movimento físico terminar (pousar), não a animação. O wait_to_finish
## do próprio StepPhysicalMove embutido é ignorado aqui.
@export var physical_move: StepPhysicalMove
