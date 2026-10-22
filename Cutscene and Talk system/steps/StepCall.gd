# talksystem/steps/StepCall.gd
class_name StepCall
extends CutsceneStep

## Chama um método (sem argumentos) em todos os nós de um grupo.
## Mesmo estilo de seleção do StepAnimation (target_group).
## O método é executado e a sequência avança logo em seguida.
## Se nenhum nó do grupo tiver o método, avisa no Output e avança.

## Grupo dos nós alvo, ex: "player".
@export var target_group: String = ""
## Nome do método a chamar, ex: "respawn".
@export var method: StringName = &""
