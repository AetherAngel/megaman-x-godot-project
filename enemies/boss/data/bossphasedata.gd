class_name BossPhaseData
extends Resource

@export_group("Trigger")
## Percentual de HP (0.0 a 1.0) abaixo do qual esta fase é ativada.
## Fase 0 normalmente tem threshold 1.0 (ativa imediatamente).
## Fase 1 pode ter 0.5 (ativa quando HP cai abaixo de 50%).
@export_range(0.0, 1.0) var hp_threshold: float = 1.0

@export_group("Behaviour")
## Patterns disponíveis nesta fase.
## O sistema escolhe entre eles baseado em weight e condition.
@export var patterns: Array[AttackPattern] = []

## Nome do estado inicial da StateMachine ao entrar nesta fase.
## ex: "Idle", "Berserker"
@export var entry_state: String = "Idle"

@export_group("Entry")
## Combo de entrada da fase (ex: a fúria). Tocado UMA vez, assim que a fase entra em vigor,
## e fica fora do pool de `patterns` — nunca é sorteado de novo.
## Se esta fase tiver invencibilidade na entrada, marque `invulnerable` nas AnimPhases do combo.
## Não use `loop` aqui. Ignorado na fase 0 (ela não "entra" por transição).
@export var entry_pattern: AttackPattern

@export_group("Selection")
enum SelectionMode {
	WEIGHTED_RANDOM,     ## sorteio ponderado por weight (comportamento anterior)
	SEQUENTIAL,          ## na ordem da lista; ao fim volta ao primeiro. Ignora weight.
	WEIGHTED_NO_REPEAT,  ## sorteio ponderado, mas nunca repete o combo anterior em seguida
}
## Como o próximo combo é escolhido dentro desta fase.
## Em todos os modos o `condition` do combo continua valendo.
@export var selection_mode: SelectionMode = SelectionMode.WEIGHTED_RANDOM

@export_group("Visuals")
## Nome do animation set para esta fase (passado ao VisualLibrary).
## ex: "magna_dragoon_phase1", "magna_dragoon_berserker"
@export var animation_set: String = ""

@export_group("Audio")
## SFX tocado ao entrar na fase (ex: rugido, transformação).
@export var entry_sfx: String = ""
## Música tocada durante esta fase. Vazio = mantém a atual.
@export var phase_music: String = ""

@export_group("Immunities")
## Tags de dano que o boss ignora nesta fase.
## ex: ["fire", "lava"] para MagnaDragoon fase 2.
@export var immune_to: Array[String] = []
