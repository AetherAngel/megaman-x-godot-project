class_name PhysicalMoveDef
extends Resource

## Sequência de PhysicalMovePhase — usada por StepPhysicalMove (cutscene)
## pra mover um Actor fisicamente (ex: Magma Dragoon saindo da lava).
##
## Nunca passa por BossAction/AttackPattern/FrameEvent — é o caminho
## separado da cutscene, usando as mesmas primitivas de física do Actor
## que o combate também usa (gravity_enabled, speed helpers). Funciona
## em qualquer Actor (Boss, Player, ou qualquer outro), não é exclusivo
## de boss nenhum.
@export var phases: Array[PhysicalMovePhase] = []
