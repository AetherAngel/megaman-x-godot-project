# player/states/Intents.gd
class_name Intents
## Vocabulário de INTENÇÕES: o que alguém quer, sem dizer qual State resolve.
## Quem pede usa StateMachine.request(intent); cada State responde por can_resolve(intent).

## "Voltar à movimentação adequada ao contexto": uma ação terminou e o Player deve
## seguir como Idle, Run ou Fall, conforme o chão e a direção do momento.
const RESUME_MOVEMENT: StringName = &"resume_movement"
