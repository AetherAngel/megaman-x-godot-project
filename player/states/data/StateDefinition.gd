# player/states/data/StateDefinition.gd
class_name StateDefinition
extends Resource

@export var state_name: String = ""
@export var state_script: GDScript          # arrasta o .gd do state aqui
@export var has_transition: bool = false
@export var visual_data: StateVisualData

@export_group("Self Managed Animation")
## Se true, este state gerencia suas próprias animações via set_anim_level().
## O VisualLibrary não chamará play_state() para trocar animações frame a frame.
## Exemplo: Hover (idle / hoveringback / hoveringfront).
@export var self_managed_anim: bool = false
