# talksystem/CutsceneEffects.gd
class_name CutsceneEffects
extends Resource

## SFX e FX de um step de cutscene.
## Usado por StepAnimation (disparado JUNTO com a animação) e por StepEffects (sozinho,
## ex: explosões depois da animação de derrota).

@export_group("SFX")
## ID do som no sounds.json (seção "sfx"). Vazio = sem som.
@export var sfx_id: String = ""
## Volume em dB. INF = usa o do JSON.
@export var sfx_volume: float = INF
## Pitch. INF = usa o do JSON.
@export var sfx_pitch: float = INF
## BURST: quantos sons a sequência toca no total (8 = oito sons individuais, um de cada vez).
## Mesmo conceito do burst_count do FX. Ignorado com sfx_until_end.
@export var sfx_count: int = 1
## SPAWN INTERVAL: tempo entre o INÍCIO de um som e o início do próximo (8 sons com 0,2 =
## sons em 0; 0,2; 0,4 ... 1,4 s). 0 = todos os sons do burst na hora. Mesmo conceito do
## spawn_interval do FX: configure o mesmo valor nos dois para ficarem na mesma cadência.
@export var sfx_interval: float = 0.15
## Repete o som, a cada sfx_interval, ATÉ O STEP TERMINAR (ignora sfx_count). Opcional.
## O step precisa durar: use wait_to_finish ou step_total_duration (StepAnimation) ou
## duration (StepEffects). Precisa de sfx_interval > 0.
@export var sfx_until_end: bool = false
## Máximo de instâncias do MESMO som tocando ao mesmo tempo. Evita empilhar sons iguais
## (que soma o volume). 1 = só toca de novo quando o anterior terminar; 0 = sem limite.
## Um som bloqueado é PULADO (não adiado): a cadência do burst não muda, e a posição dele
## na sequência é consumida. Para tocar todos, mesmo sobrepostos, use 0.
@export var sfx_max_overlap: int = 1

@export_group("FX")
## Efeito de partículas. Burst, ondas e espalhamento são configurados no próprio
## SpawnedParticleDef (burst_count, spawn_interval, position_variance, wave...).
@export var fx: SpawnedParticleDef
## Onde o FX nasce: um em cada nó deste grupo. Vazio = usa o grupo do step (no
## StepAnimation, os nós animados) ou, se não houver, o centro da câmera.
@export var fx_target_group: String = ""
## Deslocamento a partir da posição do alvo (ou do centro da câmera).
@export var fx_offset: Vector2 = Vector2.ZERO
