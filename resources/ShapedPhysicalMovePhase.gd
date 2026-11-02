class_name ShapedPhysicalMovePhase
extends PhysicalMovePhase

## Fase de movimento físico com DIREÇÃO e RITMO controlados (ex: o "J" do Shoryuken).
##
## É um PhysicalMovePhase comum — mesmos campos, mesmo PhysicalMoveDef, mesmo executor —
## com duas coisas a mais:
##   • DIREÇÃO: a velocidade vai de `velocity` (início) até `velocity_end` (fim), em linha
##     reta no tempo da fase. É isso que curva a trajetória.
##   • RITMO: `speed_curve` multiplica essa velocidade ao longo da fase (o "acelerador").
##     Ex: começa lento, explode no meio, freia perto do fim.
##
## Fórmula (p = tempo decorrido ÷ duration, de 0 a 1):
##   velocidade(p) = lerp(velocity, velocity_end, p) × speed_curve(p)
##
## COMO O ACTOR TRATA ESTA FASE: igual a `continuous` — a velocidade é ditada todo frame.
## Por isso a gravidade e o `gravity_scale` NÃO agem enquanto ela dura, e os campos
## `set_velocity`, `continuous` e `hold_horizontal` são ignorados aqui.
## Use exit = TIMER com duration > 0 (o progresso p é calculado a partir de `duration`).
##
## Contrato com o Actor (duck typing, sem dependência de classe): qualquer fase que tenha
## o método velocity_at(elapsed, flip) -> Vector2 é tratada assim. O Actor não conhece
## esta classe — se este arquivo não existir, nada no Actor quebra.
##
## Dica de uso: depois desta fase, encadeie uma fase comum (ex: set_velocity = true com
## velocity = Vector2.ZERO por ~0.1s) para "frear" e devolver o controle à gravidade.
## Sem isso, o Actor sai da fase mantendo a velocidade do último frame.

@export_group("Forma e ritmo")
## Velocidade no FIM da fase. `velocity` (do PhysicalMovePhase) é a do INÍCIO.
## Vector2.ZERO (padrão) = a velocidade vai diminuindo até parar ao fim da fase.
## Autore na orientação nativa da arte (o mesmo vale para `mirror_with_facing`).
@export var velocity_end: Vector2 = Vector2.ZERO
## Acelerador ao longo da fase. Eixo X da curva = progresso (0 a 1); eixo Y = multiplicador
## da velocidade (0 = parado, 1 = velocidade cheia).
## Vazio (null) = acelerador fixo em 1, ou seja, só a mistura velocity → velocity_end.
@export var speed_curve: Curve


## Velocidade desta fase após `elapsed` segundos. `flip` = +1 / -1 (Actor.get_facing_flip()),
## aplicado ao X só se mirror_with_facing estiver ligado — mesma regra do PhysicalMovePhase.
func velocity_at(elapsed: float, flip: int) -> Vector2:
	var p: float = 1.0 if duration <= 0.0 else clampf(elapsed / duration, 0.0, 1.0)
	var v: Vector2 = velocity.lerp(velocity_end, p)
	if mirror_with_facing:
		v.x *= flip
	var pace: float = speed_curve.sample(p) if speed_curve else 1.0
	return v * pace
