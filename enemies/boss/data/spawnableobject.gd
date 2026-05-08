class_name SpawnableObject
extends Resource

@export_group("Scene")
## Cena a instanciar. ex: res://objects/lava_column.tscn
@export_file("*.tscn") var scene_path: String = ""

@export_group("Placement")
## Offset relativo ao boss no momento do spawn.
@export var offset: Vector2 = Vector2.ZERO
## Se true, espelha offset.x com o facing do boss.
@export var flip_with_facing: bool = true
## Se true, spawna na posição do player em vez do boss.
@export var spawn_at_player: bool = false

@export_group("Behaviour")
## Tempo de vida em segundos. 0 = sem limite (o objeto cuida disso).
@export var lifetime: float = 0.0
## Dano causado ao player ao contato.
@export var damage: float = 0.0
## Tag de tipo de dano.
@export var damage_tag: String = "physical"

@export_group("FX")
## Efeito spawnado junto do objeto ao aparecer.
@export var spawn_fx: SpawnedParticleDef
