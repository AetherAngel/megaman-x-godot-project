# PlayerSpawner.gd
# Attach em um Marker2D chamado "PlayerSpawn".
# Spawna o player na posição do marker ao entrar na cena.
class_name PlayerSpawner
extends Marker2D

## Caminho para a cena do player.
@export_file("*.tscn") var player_scene: String = "res://player/player.tscn"

## Se true, spawna automaticamente no _ready().
@export var auto_spawn: bool = true

## Referência ao player spawnado. Acessível externamente (ex: Checkpoint).
var player_instance: Node = null

func _ready() -> void:
	if auto_spawn:
		spawn()


func spawn() -> Node:
	if not ResourceLoader.exists(player_scene):
		push_error("PlayerSpawner: cena não encontrada: " + player_scene)
		return null
	
	player_instance = load(player_scene).instantiate()
	player_instance.z_index = 10

	# global_position é setada antes do add_child para garantir
	# que o player já entre na cena na posição correta.
	# add_child.call_deferred evita o erro de "parent busy setting up children"
	# quando spawn() é chamado durante o _ready() da cena.
	player_instance.global_position = global_position
	get_tree().current_scene.add_child.call_deferred(player_instance)

	return player_instance
