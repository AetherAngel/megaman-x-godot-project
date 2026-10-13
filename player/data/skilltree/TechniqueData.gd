# player/data/skilltree/TechniqueData.gd
class_name TechniqueData
extends Resource

## Dados completos de uma técnica do Zero (ou qualquer personagem com sabre/técnicas).
##
## Une dois lados que antes estavam separados:
##   INPUT   → InputTechnique sub-resource (qual combinação ativa a técnica)
##   OUTCOME → dados de dano e efeito (o que a técnica faz)
##
## Os .tres de InputTechnique existentes (zero_tech_ryuenjin.tres, etc.)
## são reaproveitados como sub-resources no campo `input`.
##
## Black Zero usa os mesmos `input` .tres mas com damage_units e
## damage_type_id diferentes — zero código novo para variantes.
##
## Onde vive: ArmorData.ground_techniques / air_techniques /
##            dash_techniques / wall_techniques

@export_group("Input")
## Combinação de input que ativa esta técnica.
## Referencia os .tres existentes (zero_tech_ryuenjin.tres, etc.).
@export var input: InputTechnique

@export_group("Outcome")
## Dano base em unidades. Será consultado pelo hitbox quando implementado.
@export var damage_units: int = 1
## Tipo elemental do dano. Use as constantes de DamageType.
## &"fire", &"ice", &"electric", &"wind", &"contact"...
@export var damage_type_id: StringName = DamageType.CONTACT

@export_group("Unlock")
## Técnicas bloqueadas por padrão. Desbloqueadas via progressão de jogo.
## Técnicas básicas (WallAttack, Mikazukizan) devem ter unlocked = true.
@export var unlocked: bool = false

@export_group("Audio")
@export var sfx_name: String = ""
@export var sfx_volume: float = 0.0
@export var sfx_pitch: float = 1.0
