# talksystem/steps/StepPhysicalMove.gd
class_name StepPhysicalMove
extends CutsceneStep

## Move um Actor fisicamente durante a cutscene (ex: Magma Dragoon saindo
## da lava) — chama Actor.start_physical_move(), nunca BossAction. Mesmo
## padrão do StepAnimation: wait_to_finish = false deixa rodar junto com
## outros Steps (ex: uma StepAnimation tocando a animação de surgimento
## ao mesmo tempo que isso move o corpo).

@export var target_group: String = ""       # grupo do nó a mover, ex: "magma_dragoon"
@export var move_def: PhysicalMoveDef
@export var wait_to_finish: bool = false     # espera terminar antes de ir pro próximo step
