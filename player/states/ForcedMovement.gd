# player/states/ForcedMovement.gd
extends State

## Travessia forçada da porta do boss — animação congelada no frame
## atual, posição transladada num vetor fixo (definido pela porta),
## gravidade desligada enquanto durar.
##
## Configurado externamente via player.forced_move_direction e
## player.forced_move_speed (setados por Player.enter_forced_movement(),
## chamado pela porta) — este state só LÊ esses valores, não os define.
##
## Sai quando a porta chama player.exit_forced_movement() (ao detectar
## body_exited) — não decide por conta própria quando terminar.


func enter() -> void:
	player.gravity_enabled = false
	# speed_scale = 0 congela a animação no frame atual SEM resetar,
	# diferente de .stop() (que reinicia a animação do começo).
	player.sprite.speed_scale = 0.0
	player.velocity = player.forced_move_direction * player.forced_move_speed


func update(_delta: float) -> void:
	# Repete todo frame — defensivo, garante que nada mais (bonus_velocity,
	# conveyor, etc.) desvie da direção forçada enquanto este state ativo.
	player.velocity = player.forced_move_direction * player.forced_move_speed


func exit() -> void:
	player.gravity_enabled = true
	player.sprite.speed_scale = 1.0
