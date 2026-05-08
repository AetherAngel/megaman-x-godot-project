# player/states/ZeroGenmu.gd
extends State

# 24 frames @ 32fps = 0.75s
const CHARGE_TIME: float = 1.5
const DURATION: float = 0.75

var charge_elapsed: float = 0.0
var attack_elapsed: float = 0.0
var charged: bool = false
var attacking: bool = false

func enter() -> void:
	charge_elapsed = 0.0
	attack_elapsed = 0.0
	charged = false
	attacking = false
	player.velocity.x = 0.0
	# Usa idle enquanto carrega — pode adicionar animação de charge depois
	player.change_animation_set("idle")
	if player.sprite.sprite_frames.has_animation("idle"):
		player.sprite.play("idle")

func update(delta: float) -> void:
	player.velocity.x = 0.0

	if not attacking:
		charge_elapsed += delta

		# Soltou antes de carregar — cancela
		if not InputManager.is_action_pressed("shoot"):
			player.state_machine.change_state("Idle")
			return

		# Carregou nível 2
		if charge_elapsed >= CHARGE_TIME and not charged:
			charged = true
			print("⚡ Genmu carregado!")

		# Soltou com carga completa — dispara
		if charged and not InputManager.is_action_pressed("shoot"):
			_fire()
			return
	else:
		attack_elapsed += delta
		if not player.sprite.is_playing() or attack_elapsed >= DURATION:
			player.state_machine.change_state("Idle")

func _fire() -> void:
	attacking = true
	attack_elapsed = 0.0
	player.change_animation_set("atk_genmu")
	if player.sprite.sprite_frames.has_animation("atk_genmu"):
		player.sprite.play("atk_genmu")
	else:
		push_warning("⚠️ atk_genmu não encontrada")
		player.state_machine.change_state("Idle")
