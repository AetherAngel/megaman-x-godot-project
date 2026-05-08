class_name ObjectTypeData
extends Resource

@export_group("Scene")
## Caminho para a .tscn a ser instanciada pelo SpawnerManager.
@export_file("*.tscn") var scene_path: String = ""

@export_group("FX")
## Efeito spawnado na posição de spawn ao instanciar o objeto.
@export var spawn_effect: SpawnedParticleDef
## Efeito spawnado na posição do objeto ao emitir zero_health.
@export var death_effect: SpawnedParticleDef

@export_group("Groups")
## Grupos do Godot adicionados ao nó após spawn.
@export var group_tags: Array[String] = []
