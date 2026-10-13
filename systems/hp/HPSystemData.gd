# systems/hp/HPSystemData.gd
class_name HPSystemData
extends Resource

## Configuração de HP para uma instância de HPSystem.
## Crie um .tres por tipo de Actor (player, boss, inimigo genérico).

@export_group("Units")
## Unidades base ao inicializar. Player = 16, Boss = 32 (MMX original).
@export var base_max_units: int = 16
## Teto absoluto. Player: 32 (16 base + 8 tanks × 2). Boss: 32 fixo.
@export var unit_cap: int = 32

@export_group("Player")
## Bônus por HeartTank. MMX original: 2 unidades por tank.
## Ignorado por Boss e inimigos (character_id vazio no HPSystem).
@export var heart_tank_bonus: int = 2

@export_group("I-Frames")
## Segundos de invulnerabilidade após receber dano.
## Player: 2.0s (flash longo, como no MMX original).
## Boss:   0.5s (flash rápido).
## Inimigo: 0.0 (sem I-Frames — inimigo morre rápido ou tem lógica própria).
## O DamageHandler aplica esse valor em Actor.invulnerability após cada hit.
@export var i_frame_duration: float = 0.0

@export_group("Boss Extended HP")
## Segmentos de 32 unidades. 1 = normal. 2+ = estilo Mega Man Zero.
@export var max_segments: int = 1
## Cor de cada segmento. Index 0 = primeiro.
@export var segment_colors: Array[Color] = []
