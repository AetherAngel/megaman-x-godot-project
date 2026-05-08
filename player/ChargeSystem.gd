# player/ChargeSystem.gd
extends Node

var _player: Player    = null
var _holding: bool     = false
var _hold_time: float  = 0.0
var _charge_level: int = 0

var stock_count: int   = 0
const STOCK_MAX: int   = 4

signal charge_level_changed(level: int)
signal stock_changed(count: int)

# ── Spawn markers ────────────────────────────────────────────
@onready var spawn_right: Marker2D = null
@onready var spawn_left:  Marker2D = null

# ── FX ───────────────────────────────────────────────────────
## Aura de charge no marker ChargePoint.
## level_animations[0] = carregando, [1] = lv1, [2] = lv2.
@export var charge_fx_def: StationaryParticleDef

## Flash no ponto de spawn ao atirar — um por nível.
## Deixar nulo = sem efeito visual naquele nível.
@export_group("Shoot Effects")
@export var shoot_effect_lv1: ShootEffectDef
@export var shoot_effect_lv2: ShootEffectDef
@export var shoot_effect_lv3: ShootEffectDef

## SFX ao disparar — id do sounds.json por nível.
## Deixar vazio = sem som naquele nível.
@export var shoot_sfx_lv1: String = "shoot"
@export var shoot_sfx_lv2: String = "charged_shot1"
@export var shoot_sfx_lv3: String = "charged_shot2"

## SFX tocado ao começar a carregar (loop).
## O SoundManager vai cuidar do loop automaticamente.
@export var charging_sfx: String = "charging_shot"
@export_group("")


## Container de projéteis (acima dos layers do stage).
@export var projectile_container_path: NodePath = NodePath("")

## Z-index de cada projétil.
@export var projectile_z_index: int = 10

var _charge_fx: StationaryFX = null


# ────────────────────────────────────────────────────────────

func initialize(player: Player) -> void:
	_player = player
	call_deferred("_check_initial_stock")
	call_deferred("_setup_charge_fx")
	update_spawn_points()


func _setup_charge_fx() -> void:
	if not charge_fx_def or not _player:
		return
	var anchor: Node2D = _player.get_node_or_null("ChargePoint")
	if not anchor:
		anchor = _player
	_charge_fx = ParticleFX.create_stationary(charge_fx_def, anchor)
	_charge_fx._sprite.play()
	_charge_fx.hide_fx()


func _check_initial_stock() -> void:
	if not _player or not _player.current_character.has_stock:
		return
	if ArmorManager.has_piece("arms"):
		stock_count = STOCK_MAX
		stock_changed.emit(stock_count)


func on_arms_equipped() -> void:
	if not _player or not _player.current_character.has_stock:
		return
	stock_count = STOCK_MAX
	stock_changed.emit(stock_count)


func update_spawn_points() -> void:
	if not _player:
		return
	var is_walking := _player.velocity.x != 0 and _player.is_on_floor()
	spawn_right = _player.get_node_or_null("SpawnRight_walk" if is_walking else "SpawnRight_idle")
	spawn_left  = _player.get_node_or_null("SpawnLeft_walk"  if is_walking else "SpawnLeft_idle")
	if not spawn_right:
		spawn_right = _player.get_node_or_null("SpawnRight_idle")
	if not spawn_left:
		spawn_left  = _player.get_node_or_null("SpawnLeft_idle")


# ────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _player.state_machine.current_state_name == "Intro":
		return
	if not _player:
		return
	if not InputManager.can_process_player_input:
		return
	if GameManager.current_input_mode != GameManager.InputMode.PLAYER:
		return
	if not _player.current_character.default_weapon in ["buster", "zbuster"]:
		return
	_process_charge(delta)


func _process_charge(delta: float) -> void:
	var char_data := _player.current_character
	var inp       := char_data.charge_input
	var lv1_time  := char_data.charge_lv1_time
	var lv2_time  := char_data.charge_lv2_time
	var max_level := char_data.charge_max_level

	var pressed  := InputManager.is_action_just_pressed(inp)
	var held     := InputManager.is_action_pressed(inp)
	var released := InputManager.is_action_just_released(inp)

	if char_data.has_plasma and ArmorManager.has_piece("arms") and _is_arms_alt():
		if pressed:
			_fire(0, true)
		return

	if char_data.has_stock and ArmorManager.has_piece("arms") and not _is_arms_alt():
		if pressed:
			_holding   = true
			_hold_time = 0.0

		if _holding and held:
			_hold_time += delta
			var new_level := _calc_level(lv1_time, lv2_time, max_level)
			if new_level != _charge_level:
				_charge_level = new_level
				charge_level_changed.emit(_charge_level)
				_update_charge_fx()
				if _charge_level >= 2:
					_update_charge_fx()
					stock_count   = STOCK_MAX
					stock_changed.emit(stock_count)
					_holding      = false
					_charge_level = 0
					_hold_time    = 0.0
					charge_level_changed.emit(0)
					for i in range(2):
						await get_tree().process_frame
					_update_charge_fx()
					SoundManager.stop_sfx("charging_shot")
					return

		if released and _holding:
			_holding = false
			_fire_stock()
			_charge_level = 0
			_hold_time    = 0.0
			charge_level_changed.emit(0)
			SoundManager.stop_sfx("charging_shot")
			_update_charge_fx()

		if not held and _holding:
			_holding      = false
			_charge_level = 0
			_hold_time    = 0.0
			charge_level_changed.emit(0)
			_update_charge_fx()
		return

	if pressed:
		_holding   = true
		_hold_time = 0.0

	if _holding and held:
		_hold_time += delta
		var new_level := _calc_level(lv1_time, lv2_time, max_level)
		if new_level != _charge_level:
			_charge_level = new_level
			charge_level_changed.emit(_charge_level)
			_update_charge_fx()

	if released and _holding:
		_holding = false
		_fire(0 if _hold_time < 0.2 else _charge_level, false)
		_charge_level = 0
		_hold_time    = 0.0
		charge_level_changed.emit(0)
		_update_charge_fx()
		if SoundManager._active_sfx:
			SoundManager.stop_sfx("charging_shot")

	if not held and _holding:
		_holding      = false
		_charge_level = 0
		_hold_time    = 0.0
		charge_level_changed.emit(0)
		_update_charge_fx()


func _calc_level(lv1_time: float, lv2_time: float, max_level: int) -> int:
	if max_level >= 2 and _hold_time >= lv2_time: return 2
	elif _hold_time >= lv1_time:                   return 1
	return 0


func _update_charge_fx() -> void:
	if not _charge_fx:
		return
	if not _holding or _charge_level < 0:
		_charge_fx.hide_fx()
		# Para o loop de charging quando o botão é solto
		if not charging_sfx.is_empty():
			SoundManager.stop_loop(charging_sfx)
	else:
		_charge_fx.set_level(_charge_level, _player.facing_right)
		if _charge_level >= 0 and not charging_sfx.is_empty():
			# Passa loop_begin_sec do resource — sobrescreve o valor do JSON.
			# -1.0 = sem override (usa o JSON). Ajuste no Inspector do ChargeSystem.
				var loop_sec: float = charge_fx_def.loop_begin_sec if charge_fx_def else -1.0
				SoundManager.play_then_loop(charging_sfx, -25.0, -6.0, loop_sec)
				


# ────────────────────────────────────────────────────────────

func _fire(level: int, is_plasma: bool) -> void:
	var scene_path: String
	var speed: float

	match GameManager.current_player:
		"Zero":
			scene_path = "res://player/projectiles/ZeroProjectile.tscn"
			speed      = 600.0 if level == 0 else 750.0
		"X":
			if ArmorManager.has_piece("arms") and level == 2:
				scene_path = "res://player/objects/projectiles/Fourth_Projectile.tscn"
				speed      = 430.0
			else:
				scene_path = "res://player/objects/projectiles/XProjectile.tscn"
				match level:
					0: speed = 300.0
					1: speed = 380.0
					2: speed = 425.0
					_: speed = 600.0
		_:
			return

	if not ResourceLoader.exists(scene_path):
		push_warning("❌ ChargeSystem: projétil não encontrado: " + scene_path)
		return

	var proj: Node = load(scene_path).instantiate()
	proj.direction = Vector2.RIGHT if _player.facing_right else Vector2.LEFT
	proj.speed     = speed
	proj.level     = level
	proj.is_alt    = is_plasma
	proj.z_index   = projectile_z_index

	_get_projectile_container().add_child(proj)

	update_spawn_points()
	if spawn_right and spawn_left:
		proj.global_position = spawn_right.global_position if _player.facing_right else spawn_left.global_position
	else:
		proj.global_position = _player.global_position + Vector2(25 if _player.facing_right else -25, -20)
		push_warning("⚠️ Markers não encontrados, usando fallback.")

	_play_shoot_fx(level, proj.global_position)


	if GameManager.current_player == "X":
		_player.buster_layer.start_shoot()


func _fire_stock() -> void:
	if stock_count <= 0:
		_fire(0, false)
		return

	stock_count -= 1
	stock_changed.emit(stock_count)
	SoundManager.play_sfx("charged_shot2")

	var scene_path := "res://player/objects/projectiles/Fourth_Projectile.tscn"
	if not ResourceLoader.exists(scene_path):
		push_warning("❌ ChargeSystem: Fourth_Projectile não encontrado")
		return

	var proj: Node = load(scene_path).instantiate()
	proj.direction = Vector2.RIGHT if _player.facing_right else Vector2.LEFT
	proj.speed     = 320.0
	proj.level     = 2
	proj.is_alt    = false
	proj.z_index   = projectile_z_index

	_get_projectile_container().add_child(proj)

	update_spawn_points()

	if spawn_right and spawn_left:
		var offset := Vector2(5, -2)

		if not _player.facing_right:
			offset.x = -offset.x

		var spawn = spawn_right if _player.facing_right else spawn_left
		proj.global_position = spawn.global_position + offset
	else:
		proj.global_position = _player.global_position + Vector2(25 if _player.facing_right else -25, -20)
		push_warning("⚠️ Markers não encontrados, usando fallback.")

	_play_shoot_fx(2, proj.global_position)


	if GameManager.current_player == "X":
		_player.buster_layer.start_shoot()


func recharge_stock() -> void:
	if stock_count < STOCK_MAX:
		stock_count = STOCK_MAX
		stock_changed.emit(stock_count)


func _play_shoot_fx(level: int, pos: Vector2) -> void:
	# Efeito visual
	var fx_def: ShootEffectDef = [shoot_effect_lv1, shoot_effect_lv2, shoot_effect_lv3].get(level)
	if fx_def:
		ParticleFX.spawn_shoot_effect(fx_def, pos, _player.facing_right)

	# SFX
	var sfx_id: String = [shoot_sfx_lv1, shoot_sfx_lv2, shoot_sfx_lv3].get(level)
	if not sfx_id.is_empty():
		SoundManager.play_sfx(sfx_id)


func _get_projectile_container() -> Node:
	if not projectile_container_path.is_empty():
		var node := get_node_or_null(projectile_container_path)
		if node:
			return node
		push_warning("⚠️ ChargeSystem: projectile_container_path inválido.")
	return get_tree().current_scene


func _is_arms_alt() -> bool:
	return false
