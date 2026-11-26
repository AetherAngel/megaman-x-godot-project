# player/states/RecoveryState.gd
class_name RecoveryState
extends State
## Fase de recuperação: uma animação que toca inteira e depois passa o controle ao contexto de
## movimento, mas que cede a QUALQUER intenção do jogador, a qualquer momento. Uma recuperação
## nunca é um obstáculo entre o jogador e a próxima ação.
##
## Quem usa: Land e SaberUnequip. O filho só diz o que acontece ao entrar (_on_recovery_enter) e,
## se precisar, a cada tick (_on_recovery_tick); o resto (ceder à intenção, terminar, trava) é daqui.

## Trava de segurança, em segundos: a recuperação nunca dura mais que isso, mesmo que a animação
## não termine (ex.: animação em loop ou ausente).
@export_range(0.1, 5.0) var safety_timeout: float = 1.0

var _elapsed: float = 0.0


func enter() -> void:
	_elapsed = 0.0
	_on_recovery_enter()


func update(delta: float) -> void:
	_elapsed += delta
	_on_recovery_tick(delta)

	# Qualquer intenção (movimento ou ação) interrompe a recuperação: o contexto assume já.
	if player.intent.has_intent():
		hand_over_to_movement(delta)
		return

	# Sem intenção: a animação toca inteira e a recuperação passa o controle sozinha.
	if _is_recovery_finished() or _elapsed >= safety_timeout:
		player.state_machine.request(Intents.RESUME_MOVEMENT)


## Gancho: o que acontece ao entrar na recuperação.
func _on_recovery_enter() -> void:
	pass


## Gancho: o que acontece a cada tick, antes de decidir ceder ou terminar.
func _on_recovery_tick(_delta: float) -> void:
	pass


## A recuperação terminou? Padrão: a animação parou de tocar.
func _is_recovery_finished() -> bool:
	return not player.sprite.is_playing()
