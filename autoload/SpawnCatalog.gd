# autoload/SpawnCatalog.gd
# Adicione no Project > Project Settings > Autoload como "SpawnCatalog"
extends Node

# ─── Estrutura de entrada ────────────────────────────────────
class SpawnEntry:
	var label:    String
	var path:     String       # res:// path da PackedScene
	var category: String       # "enemy" | "item"

	func _init(p_label: String, p_path: String, p_category: String) -> void:
		label    = p_label
		path     = p_path
		category = p_category


# ─── Catálogo ────────────────────────────────────────────────
var _entries: Array[SpawnEntry] = []


func _ready() -> void:
	_register_defaults()


func _register_defaults() -> void:
	# ── Inimigos ──────────────────────────────────────────────
	# register("Nome", "res://scenes/enemies/SeuInimigo.tscn", "enemy")

	# ── Itens / Pickups ───────────────────────────────────────
	# register("Nome", "res://scenes/items/SeuItem.tscn", "item")
	pass


# ─── API pública ─────────────────────────────────────────────
func register(label: String, path: String, category: String) -> void:
	_entries.append(SpawnEntry.new(label, path, category))


func get_all() -> Array[SpawnEntry]:
	return _entries


func get_by_category(category: String) -> Array[SpawnEntry]:
	return _entries.filter(func(e: SpawnEntry) -> bool: return e.category == category)


func instantiate(entry: SpawnEntry) -> Node:
	if not ResourceLoader.exists(entry.path):
		push_error("[SpawnCatalog] Cena não encontrada: " + entry.path)
		return null
	var scene := load(entry.path) as PackedScene
	if not scene:
		push_error("[SpawnCatalog] Falha ao carregar: " + entry.path)
		return null
	return scene.instantiate()
