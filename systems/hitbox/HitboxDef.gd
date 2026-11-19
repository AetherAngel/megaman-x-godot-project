# systems/hitbox/HitboxDef.gd
class_name HitboxDef
extends Resource

## UMA hitbox de ataque: onde nasce, que forma tem, como cresce, quanto dura e o que causa.
##
## É só dado. Não conhece Boss, Player, animação nem ataque específico: quem a executa é a
## HitboxArea, e quem manda executar (um FrameEvent, um State, um script de NPC) é problema
## da camada de conexão. Autoria: embuta esta Def dentro do próprio ataque (sub-resource) e
## só a extraia para um .tres separado quando mais de um ataque a reaproveitar.
##
## "Frame" abaixo tem dois significados, escolhidos por quem chama HitboxArea.spawn():
##   - com frame_source (um AnimatedSprite2D): frame da ANIMAÇÃO;
##   - sem frame_source: tick de FÍSICA (60 por segundo).

@export_group("Identity")
## Nome da hitbox, para HITBOX_OFF / HitboxArea.clear(). Vazio = sem nome.
@export var id: StringName = &""

@export_group("Shape")
## Tamanho inicial do retângulo, em pixels.
@export var size: Vector2 = Vector2(16, 16)
## Quanto o retângulo cresce a cada frame (pixels). Negativo encolhe (mínimo 1 px).
@export var grow_per_frame: Vector2 = Vector2.ZERO
## Tamanho máximo. 0 em um eixo = sem teto nesse eixo.
@export var max_size: Vector2 = Vector2.ZERO
## Qual ponto do retângulo fica parado enquanto ele cresce (0 a 1 em cada eixo, olhando
## para a direita). (0, 0.5) = a borda de trás fica fixa e o retângulo cresce para a frente.
## (0.5, 0.5) = cresce a partir do centro. É espelhado junto com o dono.
@export var grow_anchor: Vector2 = Vector2(0.5, 0.5)

@export_group("Position")
## Onde fica o ponto de ancoragem, em relação ao pivô do dono (pixels, dono olhando para a
## direita). O X é espelhado quando o dono olha para a esquerda.
@export var offset: Vector2 = Vector2.ZERO

@export_group("Lifetime")
## Quantos frames a hitbox vive. 1 = só o frame em que nasceu. 0 = até alguém chamar
## HitboxArea.clear() (ou a animação-fonte trocar, ou o safety_timeout estourar).
## Ela nunca vive menos que 1 tick de física: é o mínimo para detectar alguém.
@export_range(0, 600) var duration_frames: int = 1
## Trava de segurança, em segundos: nenhuma hitbox fica viva além disso.
@export var safety_timeout: float = 5.0

@export_group("Damage")
## O que o golpe causa (dano, tipo e tag). Obrigatório: sem perfil, a hitbox não nasce.
@export var profile: DamageProfile
## Camadas que a hitbox enxerga. 4 = a mesma máscara do contato do Boss (atinge o Player).
@export_flags_2d_physics var target_mask: int = 4

@export_group("Priority")
## RESERVADO para a regra de prioridade (A4): ainda não é lido por nada. Maior = ganha a
## disputa quando dois hits chegam ao mesmo alvo no mesmo tick. 0 = o contato comum.
@export var priority: int = 0
