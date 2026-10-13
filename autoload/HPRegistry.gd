# autoload/HPRegistry.gd
extends Node

## Pool temporária de snapshots de HP indexada por character_id (StringName).
##
## Responsabilidades:
##   - Guardar o estado de HP de cada personagem jogável entre trocas de personagem
##   - Ser limpa ao sair da stage (via GameManager.state_changed)
##
## Boss e inimigos NÃO usam esta registry.
## O HPSystem de um boss/inimigo tem character_id vazio — sinalizador de que
## o HP é efêmero (existe apenas durante o combate daquela instância).


# ─────────────────────────────────────────────────────────────
# SNAPSHOT — estado de HP de um personagem no momento da troca
# ─────────────────────────────────────────────────────────────
class HPSnapshot:
	var current_units: int
	var max_units: int

	func _init(current: int, max_val: int) -> void:
		current_units = current
		max_units     = max_val


# ── States válidos onde HP deve persistir ─────────────────────
const _STAGE_STATES: Array = [
	# preenchido com os valores do enum após _ready()
]

# ── Pool ──────────────────────────────────────────────────────
## StringName → HPSnapshot
var _pool: Dictionary = {}


# ─────────────────────────────────────────────────────────────
# GODOT
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	# Escuta mudanças de estado do GameManager para limpar a pool
	# quando o jogador sair da stage.
	GameManager.state_changed.connect(_on_game_state_changed)


# ─────────────────────────────────────────────────────────────
# API PÚBLICA
# ─────────────────────────────────────────────────────────────

## Registra um personagem na pool com o HP máximo base.
## Se já existir snapshot (troca anterior), preserva o estado atual.
func register(character_id: StringName, base_max: int) -> void:
	if character_id.is_empty():
		return
	if _pool.has(character_id):
		return  # preserva estado existente — já jogou antes nesta stage
	_pool[character_id] = HPSnapshot.new(base_max, base_max)
	print("[HPRegistry] Registrado: '%s' — max: %d" % [character_id, base_max])


## Retorna o snapshot de um personagem. Null se não registrado.
func get_snapshot(character_id: StringName) -> HPSnapshot:
	return _pool.get(character_id, null)


## Persiste o estado atual do HPSystem antes de trocar de personagem.
func save_snapshot(character_id: StringName, current: int, max_val: int) -> void:
	if character_id.is_empty():
		return
	if not _pool.has(character_id):
		_pool[character_id] = HPSnapshot.new(current, max_val)
		return
	var snap: HPSnapshot = _pool[character_id]
	snap.current_units = current
	snap.max_units     = max_val


## Verdadeiro se o personagem já tem snapshot na pool.
func has_snapshot(character_id: StringName) -> bool:
	return _pool.has(character_id)


## Limpa toda a pool. Chamado ao sair da stage.
func clear() -> void:
	_pool.clear()
	print("[HPRegistry] Pool limpa.")


# ─────────────────────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────────────────────

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	# Limpa a pool quando o jogador sai completamente da stage/boss flow.
	# States de boss ainda estão dentro da stage — mantém HP.
	match new_state:
		GameManager.GameState.MAIN_MENU,  \
		GameManager.GameState.STAGE_SELECT, \
		GameManager.GameState.PLAYER_SELECT:
			clear()
