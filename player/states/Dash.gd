# player/states/Dash.gd
extends State

var dash_timer: float = 0.0
const DASH_DURATION := 0.45

@export var dash_spark_def: SpawnedParticleDef
@export var dash_smoke_def: SpawnedParticleDef
@export var smoke_offset: Vector2 = Vector2.ZERO
var _smoke_spawner: FXSpawner = null

func enter() -> void:

	
	player.visual_library.play_state("dash")
	var dash_dir = 1 if player.facing_right else -1
	player.horizontal_momentum = player.dash_speed * dash_dir
	player.set_horizontal_speed(player.horizontal_momentum)
	player.dash_jump_eligible = true
	player.last_state_was_dash = true
	dash_timer = DASH_DURATION
	
		# Spawnar particulas
	ParticleFX.spawn_at(dash_spark_def, Vector2.ZERO, Vector2.ZERO, player)
	var marker: Node2D = player.get_node(dash_smoke_def.marker_path)
	_smoke_spawner = ParticleFX.create_spawner(dash_smoke_def, marker, dash_smoke_def.offset)
	_smoke_spawner.owner_node = player
	_smoke_spawner.interval = dash_smoke_def.repeat_interval
	_smoke_spawner.start()
	
	

func update(delta: float) -> void:
	dash_timer -= delta
	var dash_dir = 1 if player.facing_right else -1
	player.set_horizontal_speed(player.dash_speed * dash_dir)
	
	player.set_vertical_speed(0)

	if InputManager.is_action_just_pressed("jump") and player.is_on_floor():
		# Pulo durante o dash: preserva o momentum — Jump.gd vai usar horizontal_momentum.
		player.state_machine.change_state("Jump")
		return

	if InputManager.is_action_just_pressed("dash") and player.current_armor.has_air_dash and player.can_air_dash:
		if not player.is_on_floor():
			player.state_machine.change_state("AirDash")
		else:
			return

	if _check_techniques(player.current_armor.dash_techniques):
		return

	if dash_timer <= 0:
		if not player.is_on_floor():
			player.gravity_enabled = true
			player.set_vertical_speed(0)
			player.state_machine.change_state("Fall")
			return

		# Dash terminou no chão sem pulo: zera o momentum.
		# Só o pulo durante o dash herda a velocidade — Run e Idle começam do zero.
		player.horizontal_momentum = 0.0
		player.dash_jump_eligible = false
		player.set_horizontal_speed(0)

		var dir = InputManager.get_move_axis()
		if dir != 0:
			player.state_machine.change_state("Run")
		else:
			player.state_machine.change_state("Idle")
		
func exit() -> void:
	if is_instance_valid(_smoke_spawner):
		_smoke_spawner.queue_free()
	_smoke_spawner = null
