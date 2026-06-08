# player/states/data/StateBaseVisualData.gd
class_name StateBaseVisualData
extends Resource

@export var has_transition: bool = false
@export var transition_file: String = ""   # ex: "spr_x_walk"
@export var transition_anim: String = ""   # ex: "towalk"

@export var main_file: String = ""         # ex: "spr_x_walk"
@export var main_anim: String = ""         # ex: "walkloop"
@export var is_loop: bool = true

@export var shoot_file: String = ""        # ex: "spr_x_walk_shoot"
@export var shoot_transition_anim: String = ""
@export var shoot_main_anim: String = ""   # ex: "walkshoot"

@export_group("Self Managed Animation")
## Pool de animações por nível. Índice 0 = lv0, 1 = lv1, etc.
## Usado apenas se StateDefinition.self_managed_anim = true.
## Exemplo Hover: ["idle", "hoveringback", "hoveringfront"]
@export var level_animations: Array[String] = []

## Como sincronizar os frames das layers ao mudar de nível.
## Immediate  = frame igual ao base (0 % count)
## Delay1     = 1 frame atrás do base  (frame - 1)
## Advance1   = 1 frame à frente do base (frame + 1) — estilo ArmBaseLayer walk
enum FrameSyncMode { IMMEDIATE, DELAY_1, ADVANCE_1 }
@export var frame_sync_mode: FrameSyncMode = FrameSyncMode.IMMEDIATE
