extends State

var can_cancel := false
var decision_locked := false
var hold_elapsed := 0.0
var initial_buffer_consumed := false

const CANCEL_START := 0.45     # janela pra reiniciar o combo
const HOLD_DURATION := 0.8     # tempo total antes de unequip (ajuste se quiser mais longo)

func enter() -> void:
	can_cancel = false
	decision_locked = false
	hold_elapsed = 0.0
	initial_buffer_consumed = false

	player.change_animation_set("atk_3")
	player.set_meta("came_from_attack", true)

	if player.sprite.sprite_frames.has_animation("zero_atk_3"):
		player.sprite.play("zero_atk_3")
	SoundManager.play_sfx("snd_saber", 0.0, 0.65)

	# 🔥 ANTI-INSTANT + reset limpo
	if InputManager.consume_shoot_buffer():
		print("🟢 ATK3 ENTER - buffer INICIAL consumido")
	else:
		print("🟢 ATK3 ENTER - sem buffer inicial")
	initial_buffer_consumed = true

func update(delta: float) -> void:
	if decision_locked:
		return

	hold_elapsed += delta

	# desaceleração final
	player.velocity.x *= 0.8

	# abre janela pra reiniciar combo
	if not can_cancel and hold_elapsed >= CANCEL_START:
		can_cancel = true
		print("🟡 ATK3 CAN_CANCEL ACTIVE - pode reiniciar combo")

	# 🔥 REINICIA COMBO (só com buffer NOVO)
	if can_cancel and InputManager.consume_shoot_buffer():
		decision_locked = true
		print("🔁 ATK3 → ATK1 (combo reiniciado)")
		player.combo_count = 1
		player.state_machine.change_state("ZeroAttack1")
		return

	# 🔥 TIMEOUT: agora vai pro unequip se não apertar nada
	if hold_elapsed >= HOLD_DURATION:
		decision_locked = true
		print("💀 ATK3 → UNEQUIP (timeout final)")
		player.state_machine.change_state("ZeroUnequip")
		return

func exit() -> void:
	decision_locked = true
	print("🚪 ATK3 exit")
