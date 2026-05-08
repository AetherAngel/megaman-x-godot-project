# autoload/SaveSystem.gd
extends Node

const SAVE_DIR  := "user://saves/"
const SAVE_NAME := "save_%s.tres"
const DEFAULT_SLOT := 1

var current_save: SaveData = null
var _current_slot: int = DEFAULT_SLOT


func _ready() -> void:
	DirAccess.make_dir_absolute(SAVE_DIR)
	# Tenta carregar o save padrão automaticamente ao iniciar
	if not load_from_slot(DEFAULT_SLOT):
		create_new_save(DEFAULT_SLOT)
		print("✅ SaveSystem: Nenhum save encontrado — save novo criado no slot ", DEFAULT_SLOT)
	else:
		print("✅ SaveSystem: Save carregado do slot ", DEFAULT_SLOT)


# ============================================================
# CRIAR
# ============================================================

func create_new_save(slot: int = DEFAULT_SLOT) -> void:
	_current_slot  = slot
	current_save   = SaveData.new()
	save_to_slot(slot)
	print("✅ SaveSystem: Save novo criado no slot ", slot)


# ============================================================
# SALVAR
# ============================================================

func save_to_slot(slot: int = DEFAULT_SLOT) -> void:
	if not current_save:
		push_warning("SaveSystem: Tentou salvar mas current_save é nulo!")
		return
	_current_slot = slot
	var path := _slot_path(slot)
	var err := ResourceSaver.save(current_save, path)
	if err != OK:
		push_error("SaveSystem: Erro ao salvar no slot %d → %s" % [slot, error_string(err)])
	else:
		print("✅ SaveSystem: Salvo no slot ", slot, " → ", path)


# Atalho: salva no slot atual
func save() -> void:
	save_to_slot(_current_slot)


# ============================================================
# CARREGAR
# ============================================================

func load_from_slot(slot: int = DEFAULT_SLOT) -> bool:
	var path := _slot_path(slot)
	if not ResourceLoader.exists(path):
		return false
	var data := ResourceLoader.load(path)
	if not data is SaveData:
		push_warning("SaveSystem: Arquivo no slot %d não é um SaveData válido!" % slot)
		return false
	current_save  = data
	_current_slot = slot
	print("✅ SaveSystem: Carregado slot ", slot)
	return true


# ============================================================
# RESETAR
# ============================================================

# Apaga o save do slot e cria um SaveData limpo em memória (não salva em disco ainda)
func reset_save(slot: int = DEFAULT_SLOT) -> void:
	var path := _slot_path(slot)
	if ResourceLoader.exists(path):
		DirAccess.remove_absolute(path)
		print("🗑️ SaveSystem: Save do slot ", slot, " deletado")
	current_save  = SaveData.new()
	_current_slot = slot
	print("✅ SaveSystem: Save resetado para valores padrão")


# ============================================================
# HELPERS
# ============================================================

func has_save(slot: int = DEFAULT_SLOT) -> bool:
	return ResourceLoader.exists(_slot_path(slot))


func get_current_slot() -> int:
	return _current_slot


func _slot_path(slot: int) -> String:
	return SAVE_DIR + SAVE_NAME % slot


# ============================================================
# COLETA DE DADOS DO JOGO → SAVE
# Chame isso antes de save_to_slot para garantir dados atualizados
# ============================================================

func collect_game_data() -> void:
	if not current_save:
		return

	# Armadura do X
	current_save.x_equipped_pieces = ArmorManager.get_equipped_pieces()

	# TODO: coletar lives, money, heart_tanks, subtanks, defeated_bosses
	# quando esses sistemas estiverem funcionais
