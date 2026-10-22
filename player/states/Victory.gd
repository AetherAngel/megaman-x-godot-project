# player/states/Victory.gd
extends State

## Segura o Player durante a vitória sobre o boss: sem controle, sem andar, e nenhum
## outro state sobrescreve a pose.
##
## Este state NÃO toca nenhuma animação: a pose ("Victory") e a saída ("Outro") são
## VisualSequences tocadas pela victory_cutscene da ficha do personagem, com StepAnimation
## no grupo "player" (Player.play). Assim cada animação toca uma vez só, e quem manda é a
## cutscene. Se o Player estiver no ar, a gravidade o leva ao chão; use wait_until_on_floor
## no primeiro step da sequência para a pose só começar depois que ele pousar.

## Avisa a StateMachine para não tocar o visual automático deste state.
var manages_own_visuals: bool = true


func enter() -> void:
	player.can_control = false
	player.velocity.x  = 0.0


func update(_delta: float) -> void:
	# Sem deslizar: mantém parado no X (a gravidade em Y continua valendo).
	player.velocity.x = 0.0


func exit() -> void:
	player.can_control = true
