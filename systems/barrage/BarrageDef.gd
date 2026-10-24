# systems/barrage/BarrageDef.gd
class_name BarrageDef
extends Resource

## Saraivada em "lanes": uma chuva de projéteis PARALELOS com distribuição irregular,
## mas controlada. Reutilizável por qualquer boss ou hazard (chuva de gelo, de pedras...).
##
## IDEIA CENTRAL — como todos os projéteis seguem a mesma direção, o "corredor" de cada um
## é definido só pelo X onde ele pousa no chão. A distância HORIZONTAL entre dois deles é a
## mesma em qualquer altura, e é ela que o player enxerga ao desviar (dash).
##
## Quem executa é o BarrageController. Disparo típico: FrameEvent SPAWN_FX com
## fx_resource = este Resource, numa AnimPhase com exit = ON_SIGNAL (a fase termina quando
## a saraivada termina).
##
## Linha do tempo:  [ preamble_fx contínuo ][ chuva por `duration` ][ últimos pousam ] → fim
##                  0                      start_delay
##
## ATENÇÃO — AnimPhase.signal_timeout (padrão 5 s): conta desde o INÍCIO da fase, não do
## FrameEvent. A fase só aguarda a saraivada até esse limite e depois avança forçado (o boss
## perde a invulnerabilidade e segue para o próximo combo no meio da chuva). Ajuste:
##   signal_timeout >= (tempo até o FrameEvent) + start_delay + duration + ~1,5 s de queda

@export_group("Direction")
## Ângulo da queda em relação à vertical, em graus. Positivo = cai para a ESQUERDA (nasce
## no canto superior direito, como no Meteor Fall do X4). Negativo = espelhado.
## O sprite do meteoro precisa vir desenhado na diagonal deste ângulo (o FX não gira).
@export_range(-80.0, 80.0) var fall_angle_deg: float = 35.0
## Velocidade de queda, em px/s.
@export var speed: float = 200.0

@export_group("Timing")
## Segundos entre o início da saraivada e o primeiro meteoro. Durante esse tempo roda o
## `preamble_fx`. É o ÚNICO tempo da parte 1 — não duplique no repeat_duration do FX.
@export var start_delay: float = 2.0
## Duração da janela em que novos meteoros podem nascer (depois do start_delay).
@export var duration: float = 6.0
## Segundos entre tentativas de spawn, e variação ± aplicada a cada intervalo.
@export var spawn_interval: float = 0.35
@export var interval_jitter: float = 0.1
## Máximo de meteoros no total. 0 = sem limite (só a duração limita).
@export var max_total: int = 0
## Semente do sorteio. 0 = aleatória. Com um valor fixo, a MESMA formação se repete —
## útil para validar a distribuição e para a etapa dos projéteis reais usar o mesmo padrão.
@export var seed_value: int = 0

@export_group("Lanes")
## Largura do corredor de uma trajetória (px, em X de pouso). Depois que um meteoro pousa,
## nenhum outro pode usar um X a menos de lane_width dele durante lane_cooldown.
@export var lane_width: float = 24.0
## Segundos de espera, contados do POUSO, antes de reutilizar um corredor.
@export var lane_cooldown: float = 1.0
## Distância horizontal mínima entre meteoros ATIVOS (px).
## CUIDADO: a diagonal VARRE o corpo. Para um alvo de largura w e altura h, o meteoro
## (largura m, ângulo a) cobre horizontalmente  w + m + h·tan(a)  — bem mais que a largura.
## Valores padrão validados por simulação de esquiva (jogador a 180 px/s, percepção
## atrasada 0,3 s, meteoro de até 40 px, Zero em pé 26x42 como pior caso): 100% das
## saraivadas sem acerto inevitável. Com 64 px / 45° o pior caso caía para 83%.
## Alternativa mais inclinada: ângulo 45° com min_spacing 112.
@export var min_spacing: float = 96.0
## Margem das bordas da câmera onde nenhum meteoro pousa.
@export var edge_margin: float = 16.0
## Tentativas de achar uma lane livre por tick. Sem sucesso o tick é PULADO — as regras
## nunca são relaxadas só para forçar um meteoro.
@export var max_attempts: int = 8

@export_group("Geometry")
## Distância do pivô do dono até o chão da arena (px, positivo = para baixo).
## Magma Dragoon: a base do CollisionShape2D fica ~34 px abaixo do pivô.
@export var ground_offset_y: float = 34.0
## Quanto acima do topo da câmera os meteoros nascem (px).
@export var spawn_margin: float = 24.0

@export_group("Visuals")
## FX contínuo opcional durante o start_delay (ex: a saraivada de bolas subindo da boca).
## Precisa de repeat_interval > 0. Deixe repeat_duration = 0: o controller o encerra quando
## a chuva começa. marker_path / mirror_marker_with_facing valem normalmente.
@export var preamble_fx: SpawnedParticleDef
## Visual de cada meteoro. Direção, velocidade e vida vêm da lane (spread, velocity e
## lifetime deste def são ignorados). Desligue fade_out.
@export var meteor_fx: SpawnedParticleDef

@export_group("Debug")
## Desenha na tela as lanes reservadas (ciano), o espaço mínimo entre elas, os corredores
## em cooldown (laranja) e os sorteios rejeitados (vermelho). Para ajustar os valores.
@export var debug_draw_lanes: bool = false
