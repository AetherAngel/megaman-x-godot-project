extends State

var can_cancel := false
var decision_locked := false
var hold_elapsed := 0.0
var initial_buffer_consumed := false

const CANCEL_START := 0.45
const HOLD_DURATION := 0.55   # um pouco maior que o original pra dar respiro

func enter() -> void:
	can_cancel = false
	decision_locked = false
	hold_elapsed = 0.0
	initial_buffer_consumed = false

	player.change_animation_set("atk_2")
	player.set_meta("came_from_attack", true)

	if player.sprite.sprite_frames.has_animation("zero_atk_2"):
		player.sprite.play("zero_atk_2")
	SoundManager.play_sfx("snd_saber", 0.0, 1.5)

	# 🔥 ANTI-INSTANT: consome o buffer que veio do ATK1
	if InputManager.consume_shoot_buffer():
		print("🟢 ATK2 ENTER - buffer INICIAL consumido")
	else:
		print("🟢 ATK2 ENTER - sem buffer inicial")
	initial_buffer_consumed = true

func update(delta: float) -> void:
	if decision_locked:
		return

	hold_elapsed += delta

	# desaceleração (mantive seu estilo, mas mais suave)
	player.velocity.x *= 0.85   # troquei de 0.8 pra 0.85 pra ficar mais natural

	# 🔥 ABRE JANELA DE CANCEL
	if not can_cancel and hold_elapsed >= CANCEL_START:
		can_cancel = true
		print("🟡 ATK2 CAN_CANCEL ACTIVE - janela aberta em %.3fs" % hold_elapsed)

	# 🔥 COMBO REAL (só com buffer NOVO)
	if can_cancel and InputManager.consume_shoot_buffer():
		decision_locked = true
		print("🔥 ATK2 → ATK3 (combo real)")
		player.combo_count = 3
		player.state_machine.change_state("ZeroAttack3")
		return

	# timeout normal
	if hold_elapsed >= HOLD_DURATION:
		decision_locked = true
		print("💀 ATK2 → UNEQUIP (timeout)")
		player.state_machine.change_state("ZeroUnequip")
		return

func exit() -> void:
	decision_locked = true
	print("🚪 ATK2 exit")
