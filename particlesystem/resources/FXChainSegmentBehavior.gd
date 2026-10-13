class_name FXChainSegmentBehavior
extends Resource

## Comportamento de UM segmento específico da cadeia, por posição.
##
## A POSIÇÃO nunca é controlada aqui — todo segmento persegue e se
## posiciona desde o instante em que nasce (ver FXChainSegment). Este
## recurso controla DUAS coisas independentes:
##   1. Quando o PRÓXIMO elo da cadeia é criado (grupo "Criação do
##      próximo elo") — isso é o que faz a cauda crescer em cascata,
##      um elo de cada vez.
##   2. A VISIBILIDADE deste próprio segmento (grupo "Visibilidade") —
##      puramente cosmético, não afeta quando o próximo nasce.
##
## Preenchido em FXChainDef.segment_behaviors — um item por segmento, na
## mesma ordem de sempre: [0] = Segmento 1 (mais perto da cabeça) ...
## Totalmente opcional — sem entrada correspondente, o próximo elo nasce
## por tempo fixo (FXChainDef.segment_interval) e este segmento nasce
## visível, sem toggle.

enum LoopPoint { START, HALF, END }

@export_group("Criação do próximo elo")
## Se true, o PRÓXIMO elo da cadeia só é criado quando ESTE segmento
## atingir o ponto do PRÓPRIO loop configurado em spawn_next_at. Se
## false (padrão), usa o tempo fixo de FXChainDef.segment_interval,
## contado a partir da criação deste segmento. Não se aplica ao último
## segmento da cadeia (não existe próximo).
@export var spawn_next_on_loop: bool = false

## Em qual ponto do PRÓPRIO loop deste segmento o próximo elo é criado.
## Só usado se spawn_next_on_loop = true.
@export var spawn_next_at: LoopPoint = LoopPoint.START

@export_group("Visibilidade")
## Se este segmento já nasce visível, ou começa invisível (útil
## combinado com toggle_visibility abaixo).
@export var start_visible: bool = true

## Se true, ativa o marcador de início/metade/fim do loop abaixo pra
## alternar (toggle) a visibilidade deste segmento — puramente
## cosmético, não tem relação com spawn_next_on_loop acima.
@export var toggle_visibility: bool = false

## Se o toggle observa o loop do segmento ANTERIOR da cadeia (o leader
## deste segmento). Necessário pra toggle_visibility funcionar. Não se
## aplica ao Segmento 1 (índice 0) — ele não tem anterior.
@export var related_to_previous: bool = false

## Em qual ponto do loop do segmento observado o toggle de visibilidade
## acontece. Só usado se toggle_visibility = true.
@export var loop_point: LoopPoint = LoopPoint.START

## Só tem efeito se toggle_visibility = true. Marcado: o toggle acontece
## toda vez que o loop observado passar pelo ponto marcado. Desmarcado:
## o toggle acontece só uma vez.
@export var continuous_toggle: bool = false

@export_group("Vida")
## Tempo máximo (segundos) que este segmento existe, mesmo que nunca
## receba remove_segment() via dominó. 0 = sem limite (padrão).
@export var max_lifetime: float = 0.0
