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
