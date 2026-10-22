# talksystem/CutsceneStep.gd
class_name CutsceneStep
extends Resource

# Base class — não usar diretamente
# Criar subclasses: StepDialogue, StepWait, StepAnimation, StepChangeScene

## Se true, ESTE step é pulado quando a cutscene já foi vista nesta partida
## (ex: marcar só as falas da intro de um boss para não repeti-las ao tentar de novo).
## Os demais steps continuam rodando normalmente. Para pular a cutscene INTEIRA,
## use CutsceneData.skip_if_seen.
@export var skip_if_seen: bool = false
