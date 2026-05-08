class_name BossAttack
extends Resource

@export_group("Identity")
@export var attack_id: String = ""

@export_group("Animation")
## Animação tocada durante este ataque.
@export var animation: String = ""
## Se true, aguarda a animação terminar antes de avançar.
@export var wait_for_animation: bool = true
## Duração máxima em segundos. 0 = sem limite (usa wait_for_animation).
@export var duration: float = 0.0

@export_group("Damage")
@export var damage: float = 0.0
## Tag de tipo de dano. ex: "fire", "physical", "energy"
@export var damage_tag: String = "physical"

@export_group("Spawning")
## Objetos spawnados durante este ataque.
## Cada um é instanciado pelo SpawnerManager no momento certo.
@export var spawn_objects: Array[SpawnableObject] = []
## Frame da animação em que os objetos são spawnados. -1 = imediato.
@export var spawn_on_frame: int = -1

@export_group("Audio")
@export var sfx: String = ""
@export var sfx_volume: float = INF

@export_group("FX")
@export var fx_def: SpawnedParticleDef
