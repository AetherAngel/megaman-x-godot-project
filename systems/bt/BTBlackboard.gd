# systems/bt/BTBlackboard.gd
class_name BTBlackboard
extends RefCounted

## Contexto de leitura para um único tick da Behavior Tree.
## Criado do zero a cada frame pelo BTRunner — nunca compartilhado entre frames.
## BTCondition e BossAction lêem daqui. Nunca escrevem de volta.

const HP_RATIO        := &"hp_ratio"
const DISTANCE_PLAYER := &"distance_to_player"
const PLAYER_POSITION := &"player_position"
const PLAYER_REF       := &"player_ref"  # o Node do player — BTAction usa pra chamar actor.select_pattern(player_ref)
const CURRENT_PHASE   := &"current_phase"
const DELTA           := &"delta"

# ── Flags espaciais (porte de AttackPattern.condition) ─────────
# Armazenadas como float 1.0/0.0 — BTCondition já lê qualquer
# chave como float, então EQUAL 1.0 funciona sem mudar BTCondition.
# Escalável: uma condição espacial nova = uma const aqui +
# uma linha em BTRunner._compute_spatial_flags().
const PLAYER_NEAR_WALL := &"player_near_wall"
const PLAYER_ABOVE     := &"player_above"
const PLAYER_BELOW     := &"player_below"
const PLAYER_CLOSE     := &"player_close"
const PLAYER_FAR       := &"player_far"

var _data: Dictionary = {}


func set_value(key: StringName, value: Variant) -> void:
	_data[key] = value


func get_value(key: StringName, default: Variant = null) -> Variant:
	return _data.get(key, default)


func has(key: StringName) -> bool:
	return _data.has(key)
