class_name FXChainSegmentDef
extends Resource

## Define o visual de UM segmento de uma cadeia (o "elo" — ex: um pedaço
## da cauda de fogo do Hadouken, um anel do corpo de um dragão).
##
## O movimento NÃO é definido aqui — é 100% resultado de perseguir o
## segmento da frente (ver FXChainSegment). Por isso não existe velocity,
## gravity ou fases aqui: só o visual que fica se repetindo em loop.

@export_group("Visual")
@export var sprite_frames: SpriteFrames
## Animação única, tocada em loop contínuo enquanto o segmento existe.
@export var animation: String = "default"
@export var segment_scale: Vector2 = Vector2.ONE
@export var z_index: int = 10
