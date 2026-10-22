class_name BossData
extends Resource

@export_group("Identity")
@export var boss_name: String = ""
@export var boss_id: String = ""          # ex: "magma_dragoon" — usado para paths

@export_group("Visuals")
@export var sprite_frames: SpriteFrames  # spr_boss_nome.tres
@export var name_card_texture: Texture2D # textura exibida na BOSS_PRESENTATION

@export_group("Stats")
## Unidades de HP do boss. MMX original: sempre 32 (teto máximo da barra).
## Este valor é informativo — a fonte de verdade em runtime é HPSystem.
## O HPSystem lê base_max_units do HPSystemData atribuído ao node HPSystem no .tscn.
@export var hp_units: int = 32

## Segmentos da barra de HP. 1 = normal (padrão MMX).
## 2+ = estilo Mega Man Zero: a barra reabastece mudando de cor a cada 32 unidades.
## Configurado também no HPSystemData do node HPSystem — este campo serve de referência
## e pode ser usado para popular o HPSystemData via code no _ready() se necessário.
@export var max_segments: int = 1

@export_group("Damage Resistance")
## Tabela de resistência/fraqueza por tipo de dano.
## Crie um .tres de DamageResistanceTable em:
##   res://enemies/boss/data/resistance_tables/<boss_id>_resistance.tres
## Arraste aqui no editor.
## Null = sem tabela, todo dano é tratado como default (1 unidade).
@export var resistance_table: DamageResistanceTable

@export_group("Arena")
@export var arena_bounds: Rect2 = Rect2(0, 0, 320, 224)

@export_group("Facing")
## A arte deste boss (sprite_frames) já é desenhada olhando pra direita?
## true (padrão) = arte nativa olha pra direita — a maioria dos bosses.
## false = arte nativa olha pra esquerda (ex: Magma Dragoon) — Boss.set_facing()
## inverte a lógica de flip_h automaticamente pra esse caso.
@export var native_facing_right: bool = true

## Direção que o boss deve estar olhando ao começar a luta (chamado em
## Boss._start()). Depende de onde ele nasce na arena em relação ao
## player — a maioria começa à esquerda olhando pra direita, mas alguns
## (ex: Magma Dragoon) começam à direita olhando pra esquerda.
@export var starts_facing_right: bool = true

@export_group("Phases")
## Fases em ordem. Fase 0 = início da batalha.
## O PhaseSystem avalia em ordem e ativa a primeira cujo threshold seja atingido.
@export var phases: Array[BossPhaseData] = []

@export_group("Flow")
## CutsceneData tocada durante BOSS_INTRO.
@export var intro_cutscene: CutsceneData

## Se true, exibe diálogo final antes de WEAPON_GET.
@export var has_final_dialogue: bool = false
## DialogueData tocada durante BOSS_FINAL_DIALOGUE.
@export var final_dialogue: DialogueData
## CutsceneData tocada depois da fala final: animação de derrota, destruição (StepCall
## "play_destruction" no grupo "boss"), espera... O boss fica vivo até ela. Sem cutscene,
## o boss é destruído direto.
@export var defeat_cutscene: CutsceneData

@export_group("Reward")
@export var weapon_reward: WeaponRewardData
