class_name PhysicalMovePhase
extends Resource

## Um "degrau" de uma sequência de movimento físico (ver PhysicalMoveDef).
## Usa só as primitivas que o Actor já tem — a escala de gravidade e as
## speed helpers — nada de física nova, só quem decide quando aplicar
## o quê.

enum ExitOn { TIMER, APEX, LANDING }

@export_group("Movimento")
## Se true, define `velocity` ao entrar nesta fase (sobrescreve os dois
## eixos de uma vez). Se false, não mexe na velocidade — deixa o que a
## fase anterior (ou a gravidade) já estabeleceu continuar.
@export var set_velocity: bool = false
## Se true, reaplica phase.velocity todo frame enquanto a fase estiver ativa.
## A fase ainda sai pelo ExitOn ou pelo stop_physical_move (timer chefe).
@export var continuous: bool = false
## Se true (e set_velocity = true), reaplica SÓ o X de `velocity` todo frame.
## Recupera a velocidade horizontal perdida em colisão com parede, sem mexer
## no Y — a gravidade e a queda continuam normais (diferente de `continuous`).
@export var hold_horizontal: bool = false
@export var velocity: Vector2 = Vector2.ZERO
## Se true, o X de `velocity` é espelhado quando o ator está virado para o lado OPOSTO ao da
## orientação nativa da arte (Actor.get_facing_flip()). Autore a velocidade na orientação
## nativa: o mesmo movimento serve para os dois lados (ex: NoseDive, pulo de volta à arena).
## Desligado (padrão) = velocidade absoluta, como sempre foi (ex: intro do Magma Dragoon).
@export var mirror_with_facing: bool = false
## Multiplica a gravidade normal do Actor durante esta fase.
## 1.0 = igual sempre foi. 0.0 = suspensa (ex: "ficar parado no ar").
## >1.0 = mais pesada que o normal (ex: arrasto na subida, ainda
## subindo mas "pesadão" — a gravidade não impede a subida, só freia).
@export_range(0.0, 3.0, 0.05) var gravity_scale: float = 1.0

@export_group("Saída")
## TIMER = depois de `duration` segundos.
## APEX = quando a velocidade vertical cruza de subindo pra descendo
##        (só aceita depois de ter estado subindo de verdade).
## LANDING = ao tocar o chão (is_on_floor()).
@export var exit: ExitOn = ExitOn.TIMER
## Só usado se exit = TIMER.
@export var duration: float = 0.3

@export_group("Visual (opcional)")
## Nome de animação a tocar ao entrar nesta fase. Vazio = não mexe.
## Actor só avisa (physical_move_phase_entered) — quem escuta decide
## o que "animation" significa (ex: Boss chama seu set_visual_state()).
@export var animation: String = ""
## FX a spawnar na posição do Actor ao entrar nesta fase.
@export var fx: SpawnedParticleDef
