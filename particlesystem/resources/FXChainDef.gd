class_name FXChainDef
extends Resource

## Define uma cadeia segmentada genérica — a cauda de um Hadouken, o corpo
## de um dragão, uma corrente, um chicote, uma serpente. Qualquer coisa em
## que N segmentos perseguem exclusivamente o segmento imediatamente à
## frente, com um atraso fixo (tipo fila de patinho).
##
## A cabeça (o objeto que realmente se move) NÃO faz parte deste recurso —
## é um Node2D externo passado em ParticleFX.spawn_chain(). Este recurso
## cuida só dos segmentos que perseguem essa cabeça.
##
## Reutilizável: pra criar uma cadeia nova (dragão, chicote, etc.), basta
## um FXChainSegmentDef com o visual certo — a lógica de perseguição e
## destruição em dominó é a mesma pra qualquer uso.

@export_group("Visual")
## Definição compartilhada por TODOS os segmentos da cadeia.
@export var segment_def: FXChainSegmentDef

@export_group("Cadeia")
## Quantos segmentos a cadeia tem (ex: 6 pra cauda do Hadouken).
@export var segment_count: int = 6
## Atraso de POSIÇÃO em segundos entre um segmento e o próximo — quanto
## maior, mais "esticada"/espaçada fica a cadeia. Só afeta o espaçamento
## visual, não o ritmo de quando cada um nasce (isso é spawn_interval,
## abaixo).
@export var segment_interval: float = 0.08
## Ritmo em segundos entre a CRIAÇÃO de um segmento e do próximo, quando
## o segmento usa o gatilho padrão por tempo (spawn_next_on_loop = false
## no FXChainSegmentBehavior dele, ou nenhum behavior configurado). Não
## afeta espaçamento visual — só quando cada elo aparece. Segmentos com
## spawn_next_on_loop = true ignoram este valor (usam o loop deles).
@export var spawn_interval: float = 0.1

@export_group("Spawn")
## Atraso em segundos entre a chamada de spawn_chain() e o Segmento 1
## começar a existir. Garante que a cadeia nunca apareça no mesmo frame
## que a cabeça.
@export var spawn_delay: float = 0.05

@export_group("Facing")
enum FlipMode {
	NONE,             ## segmentos nunca flipam (padrão, comportamento de hoje)
	ALL_FOLLOW_HEAD,  ## todos os segmentos flipam junto com facing_right da cabeça
	PER_SEGMENT,      ## cada segmento decide via FXChainSegmentVisual.flip_with_facing
}
## Controla se/como os segmentos acompanham o facing da cabeça (o mesmo
## facing_right que o SpawnableObject já usa). NONE = nunca flipa.
@export var flip_mode: FlipMode = FlipMode.NONE

@export_group("Visual por segmento")
## Offset aplicado a TODOS os segmentos da cadeia de uma vez, somado ao
## offset individual de cada um (se houver, em FXChainSegmentVisual).
## Útil pra deslocar a cauda inteira sem precisar mexer segmento por
## segmento.
@export var body_offset: Vector2 = Vector2.ZERO
## Personalização individual de cada segmento (frame fixo, offset,
## z_index, flip), editável no editor. Um item por segmento — [0] =
## Segmento 1 (mais perto da cabeça). Se a lista for menor que
## segment_count, os segmentos sem entrada correspondente usam o visual
## padrão de segment_def (anima normalmente, offset zero, z_index do
## segment_def).
@export var segment_visuals: Array[FXChainSegmentVisual] = []
## Ciclo de vida individual de cada segmento (revelação relativa ao
## anterior, vida máxima), editável no editor. Mesma ordem/regra de
## índice que segment_visuals acima — totalmente independente dele.
@export var segment_behaviors: Array[FXChainSegmentBehavior] = []

@export_group("Destruição")
## Intervalo em segundos entre a remoção de cada segmento no efeito
## dominó, disparado por FXChainController.on_hit(). O Segmento 1 (mais
## perto da cabeça) é removido por último.
@export var domino_delay: float = 0.1
## Define se a destruição do dominó começa pelo primeiro segmento.
## False preserva a ordem atual, do último para o primeiro.
@export var domino_forward: bool = false
