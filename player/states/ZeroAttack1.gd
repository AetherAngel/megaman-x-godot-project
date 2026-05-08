extends State

var can_cancel := false
var decision_locked := false
var hold_elapsed := 0.0
var initial_buffer_consumed := false

const CANCEL_START := 0.45     # 🔥 AUMENTADO - agora o atk_1 tem peso de verdade
const HOLD_DURATION := 0.75    # um pouquinho mais pra dar folga

func enter() -> void:
	can_cancel = false
	decision_locked = false
	hold_elapsed = 0.0
	initial_buffer_consumed = false

	player.change_animation_set("atk_1")
	player.set_meta("came_from_attack", true)

	if player.sprite.sprite_frames.has_animation("zero_atk_1"):
		player.sprite.play("zero_atk_1")
	SoundManager.play_sfx("snd_saber")

	# 🔥 come o buffer do input que iniciou o ataque (anti-instant)
	if InputManager.consume_shoot_buffer():
		print("🟢 ATK1 ENTER - buffer INICIAL consumido")
	else:
		print("🟢 ATK1 ENTER - sem buffer inicial")
	initial_buffer_consumed = true

func update(delta: float) -> void:
	if decision_locked:
		return

	hold_elapsed += delta

	# desaceleração leve
	player.lerp_stop_horizontal(0.0, 12.0 * delta)

	# abre janela de cancel (só depois de 0.25s)
	if not can_cancel and hold_elapsed >= CANCEL_START:
		can_cancel = true
		print("🟡 ATK1 CAN_CANCEL ACTIVE - janela aberta em %.3fs" % hold_elapsed)

	# 🔥 COMBO SÓ AQUI: buffer NOVO + janela aberta
	if can_cancel and InputManager.consume_shoot_buffer():
		decision_locked = true
		print("🔥 ATK1 → ATK2 (combo real - buffer novo consumido)")
		player.combo_count = 2
		player.state_machine.change_state("ZeroAttack2")
		return

	# timeout normal
	if hold_elapsed >= HOLD_DURATION:
		decision_locked = true
		print("💀 ATK1 → UNEQUIP (timeout)")
		player.state_machine.change_state("ZeroUnequip")
		return

func exit() -> void:
	decision_locked = true
	print("🚪 ATK1 exit")
