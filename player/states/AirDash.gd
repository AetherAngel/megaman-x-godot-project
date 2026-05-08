extends State

var dash_time := 0.35
var timer := 0.0


func enter() -> void:
	if not player.current_armor.has_air_dash or not player.can_air_dash:
		player.state_machine.change_state("Fall")
		return

	player.can_air_dash = false

	# CORREÇÃO: desativa gravidade durante o dash.
	# Antes: gravity_enabled nunca era falso → Actor aplicava gravidade todo frame
	#        e set_vertical_speed(0) era imediatamente sobrescrito → player caía.
	player.gravity_enabled = false

	player.change_animation_set("airdash")
	if player.sprite.sprite_frames.has_animation("airdash"):
		player.sprite.play("airdash")

	var dir = 1 if player.facing_right else -1
	player.set_horizontal_speed(player.dash_speed * dir)
	player.set_vertical_speed(0.0)

	timer = dash_time


func update(delta: float) -> void:
	timer -= delta

	var dir = 1 if player.facing_right else -1
	player.set_horizontal_speed(player.dash_speed * dir)
	player.set_vertical_speed(0.0)

	if player.sprite.animation != "airdash":
		player.sprite.play("airdash")

	if timer <= 0:
		# Reativa gravidade antes de cair.
		player.gravity_enabled = true
		player.state_machine.change_state("Fall")
		return  # CORREÇÃO: return era ausente — código continuava executando após change_state.


func exit() -> void:
	# Garante que a gravidade volta mesmo se o state for interrompido por outro estado.
	player.gravity_enabled = true
