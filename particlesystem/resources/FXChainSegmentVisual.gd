class_name FXChainSegmentVisual
extends Resource

## Personalização visual de UM segmento específico da cadeia, por posição.
## Preenchido em FXChainDef.segment_visuals — um item por segmento, na
## mesma ordem de sempre: [0] = Segmento 1 (mais perto da cabeça) ...
## último = mais distante.
##
## Totalmente opcional — um segmento sem entrada correspondente usa o
## comportamento padrão (anima em loop, offset zero, z_index do
## FXChainSegmentDef), exatamente como já era antes deste recurso existir.

## Frame estático (índice dentro de sprite_frames/animation do
## FXChainSegmentDef) que este segmento mostra, travado — não anima.
## Ignorado se `loop_frames` estiver preenchido. -1 = não usa frame fixo.
@export var frame: int = -1

## Loop customizado: em vez de tocar a animação inteira OU travar num
## frame fixo, cicla indefinidamente pelos frames listados aqui, na ordem
## em que aparecem (ex: [2, 5, 1] → 2 → 5 → 1 → 2 → 5 → 1 ...). Tem
## prioridade sobre `frame` se preenchido. Vazio = não usa (padrão).
@export var loop_frames: Array[int] = []
## Segundos entre cada frame do loop customizado acima.
@export var loop_frame_interval: float = 0.1

## Offset aplicado em cima da posição perseguida (histórico + atraso).
## Útil pra corrigir pivot do sprite ou dar uma variação orgânica entre
## os segmentos.
@export var offset: Vector2 = Vector2.ZERO

## Z index deste segmento específico — controla a ordem de camadas entre
## os segmentos da mesma cadeia (ex: os mais perto da cabeça por cima dos
## mais distantes, ou o contrário).
@export var z_index: int = 10

@export_group("Facing")
## Se este segmento acompanha o facing da cabeça (flip horizontal). Só
## tem efeito quando FXChainDef.flip_mode = PER_SEGMENT — nesse modo,
## cada segmento decide por si; nos outros modos (NONE/ALL_FOLLOW_HEAD)
## este campo é ignorado.
@export var flip_with_facing: bool = true
