# player/PlayerIntent.gd
class_name PlayerIntent
extends RefCounted
## O que o jogador QUER fazer agora, como perguntas semânticas. Os States perguntam aqui em vez
## de ler botões: "quer pular?" em vez de "o botão de pulo acabou de ser apertado?".
##
## A implementação padrão lê o InputManager (teclado e controle). Quem precisa de outra origem
## (cutscene, IA, teste) faz uma subclasse e sobrescreve as perguntas, sem tocar nos States.
## As perguntas de ação valem para a intenção NOVA deste tick (o que Idle e Run já usam).


## Direção horizontal desejada: -1.0 (esquerda) a 1.0 (direita). 0.0 = sem intenção de se mover.
func move_direction() -> float:
	return InputManager.get_move_axis()


## Quer pular? (intenção nova neste tick)
func wants_jump() -> bool:
	return InputManager.is_action_just_pressed("jump")


## Quer dar um dash? (intenção nova neste tick)
func wants_dash() -> bool:
	return InputManager.is_action_just_pressed("dash")


## Quer atacar? (intenção nova neste tick)
func wants_attack() -> bool:
	return InputManager.is_action_just_pressed("shoot")


## Quer usar a arma especial? (intenção nova neste tick)
func wants_special_weapon() -> bool:
	return InputManager.is_action_just_pressed("special_weapon")


## Há QUALQUER intenção agora? Derivada das perguntas acima: uma subclasse que sobrescreve as
## perguntas já ganha esta de graça. Intenção de ação nova entra aqui quando ganhar uma pergunta.
func has_intent() -> bool:
	return move_direction() != 0.0 or wants_jump() or wants_dash() or wants_attack() or wants_special_weapon()
