class_name BossData
extends Resource

@export_group("Identity")
@export var boss_name: String = ""
@export var boss_id: String = ""          # ex: "magna_dragoon" — usado para paths

@export_group("Visuals")
@export var sprite_frames: SpriteFrames  # spr_boss_nome.tres
@export var name_card_texture: Texture2D # textura exibida na BOSS_PRESENTATION

@export_group("Stats")
@export var hp_total: float = 1000.0
@export var arena_bounds: Rect2 = Rect2(0, 0, 320, 224)

@export_group("Phases")
## Fases em ordem. Fase 0 = início da batalha.
## O PhaseSystem avalia em ordem e ativa a primeira cujo threshold seja atingido.
@export var phases: Array[BossPhaseData] = []

@export_group("Flow")
## CutsceneData tocada durante BOSS_INTRO.
## Pode ter StepDialogue, StepWait, StepAnimation.
@export var intro_cutscene: CutsceneData

## Se true, exibe diálogo final antes de WEAPON_GET.
@export var has_final_dialogue: bool = false
## DialogueData tocada durante BOSS_FINAL_DIALOGUE.
@export var final_dialogue: DialogueData

@export_group("Reward")
@export var weapon_reward: WeaponData
