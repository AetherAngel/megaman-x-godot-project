class_name FXSpawner
extends Node2D

## Definição do efeito a ser spawnado em loop.
@export var definition: SpawnedParticleDef
## Intervalo em segundos entre cada burst. Menor = mais partículas.
@export var interval: float = 0.05
## Se true, inicia automaticamente no _ready().
@export var auto_start: bool = false
## Direção base do spawn. Pode ser sobrescrita por código com set_direction().
@export var spawn_direction: Vector2 = Vector2.UP

var _active: bool = false
var _timer:  float = 0.0


func _ready() -> void:
	if auto_start:
		start()


func _process(delta: float) -> void:
	if not _active or not definition:
		return

	_timer += delta
	if _timer >= interval:
		_timer -= interval
		_do_spawn()


# ── API ──────────────────────────────────────────────────────

func start() -> void:
	_active = true
	_timer  = 0.0
	_do_spawn()  # spawn imediato ao iniciar, sem esperar o primeiro interval


func stop() -> void:
	_active = false


func set_direction(dir: Vector2) -> void:
	spawn_direction = dir


# ── Interno ──────────────────────────────────────────────────

func _do_spawn() -> void:
	if ParticleFX and definition:
		ParticleFX.spawn_at(definition, global_position, spawn_direction)
