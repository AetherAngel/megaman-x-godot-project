class_name FXAttachment
extends Resource

## Identificador usado para acionar por código:
##   player.fx_component.start("wall_smoke")
@export var fx_name: String = ""

## O efeito. Aceita qualquer Def do sistema:
##   SpawnedParticleDef, StationaryParticleDef, DynamicParticleDef, ShootEffectDef.
@export var effect: Resource

## NodePath relativo ao nó dono do FXComponent.
## Se vazio, usa a posição do próprio dono.
@export var marker_path: NodePath = NodePath("")

## Se true, inicia automaticamente no _ready().
@export var auto_start: bool = false

## Offset adicional aplicado em relação ao marker (em pixels).
@export var offset: Vector2 = Vector2.ZERO
