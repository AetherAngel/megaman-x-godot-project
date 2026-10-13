# autoload/CharacterManagement.gd
extends Node

## Gerenciamento centralizado de personagens jogáveis.
##
## Responsabilidades:
##   - Manter o roster de personagens disponíveis na stage atual
##   - Ser o ÚNICO ponto de entrada para trocas de personagem
##   - Notificar todos os sistemas via signals (HPRegistry, Player, HUD)
##   - Manter GameManager.current_player sincronizado (compatibilidade legada)
##
## Como adicionar um novo personagem ao roster:
##   1. Crie o .tres de PlayerCharacterData com o novo character_id
##   2. No editor Godot, selecione o Autoload CharacterManagement
##   3. Arraste o novo .tres para o array "Roster Data"
##   Pronto — zero código novo necessário.


# ─────────────────────────────────────────────────────────────
# CONFIGURAÇÃO — definida no editor Godot (Autoload inspector)
# ─────────────────────────────────────────────────────────────

## Lista de todos os personagens disponíveis no projeto.
## Arraste os PlayerCharacterData .tres aqui no editor.
## Ex: x_character.tres, zero_character.tres, axl_character.tres
@export var roster_data: Array[PlayerCharacterData] = []


# ─────────────────────────────────────────────────────────────
# ESTADO INTERNO
# ─────────────────────────────────────────────────────────────

## StringName → PlayerCharacterData
var _roster: Dictionary = {}
## Preserva a ordem de registro para cycle_next()
var _order: Array[StringName] = []
var _active_id: StringName = &""


# ─────────────────────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────────────────────

## Emitido ANTES da troca — sistemas salvam estado (ex: HPRegistry.save_snapshot)
signal character_pre_switch(old_id: StringName)
## Emitido APÓS a troca — Player e HUD reagem ao novo personagem
signal character_switched(new_id: StringName)
## Emitido quando um personagem é adicionado ou removido do roster
signal roster_changed()


# ─────────────────────────────────────────────────────────────
# GODOT
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	# Popula o roster interno a partir do array configurado no editor
	for data in roster_data:
		_register_internal(data)


# ─────────────────────────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────────────────────────

## Define qual personagem está ativo ao iniciar a stage.
## Chamado por Player._ready() após conectar os signals.
## Não emite character_switched — o Player já inicializa com os dados corretos.
func set_initial(id: StringName) -> void:
	if not _roster.has(id):
		push_error("[CharacterManagement] set_initial: ID não registrado: '%s'" % id)
		return
	_active_id = id
	_sync_game_manager()
	print("[CharacterManagement] Personagem inicial: '%s'" % id)


## Registra um personagem no roster em runtime (caso necessário).
## Normalmente o roster é populado via roster_data no editor.
func register(data: PlayerCharacterData) -> void:
	_register_internal(data)
	roster_changed.emit()


## Limpa o roster ao sair da stage.
## HPRegistry.clear() é chamado automaticamente via GameManager.state_changed.
func clear_roster() -> void:
	_roster.clear()
	_order.clear()
	_active_id = &""
	roster_changed.emit()
	print("[CharacterManagement] Roster limpo.")


# ─────────────────────────────────────────────────────────────
# SWITCH — ÚNICO ponto de entrada para trocar de personagem
# ─────────────────────────────────────────────────────────────

## Troca para o personagem com o ID informado.
## 1. Emite character_pre_switch → HPSystem salva snapshot via HPRegistry
## 2. Atualiza _active_id e sincroniza GameManager
## 3. Emite character_switched → Player e HUD reagem
func switch_to(new_id: StringName) -> void:
	if new_id == _active_id:
		return
	if not _roster.has(new_id):
		push_error("[CharacterManagement] switch_to: ID não registrado: '%s'" % new_id)
		return

	var old_id := _active_id
	character_pre_switch.emit(old_id)

	_active_id = new_id
	_sync_game_manager()

	character_switched.emit(new_id)
	print("[CharacterManagement] Trocou: '%s' → '%s'" % [old_id, new_id])


## Cicla para o próximo personagem disponível no roster (ordem de registro).
## Substitui o array hardcoded ["X", "Zero"] do DebugPanel.
func cycle_next() -> void:
	if _order.size() <= 1:
		return
	var idx := _order.find(_active_id)
	var next := (idx + 1) % _order.size()
	switch_to(_order[next])


# ─────────────────────────────────────────────────────────────
# QUERY
# ─────────────────────────────────────────────────────────────

func get_active_data() -> PlayerCharacterData:
	if _active_id.is_empty():
		return null
	return _roster.get(_active_id, null)

func get_active_id() -> StringName:
	return _active_id

func get_data(id: StringName) -> PlayerCharacterData:
	return _roster.get(id, null)

## Retorna todos os personagens do roster na ordem de registro.
func get_roster() -> Array[PlayerCharacterData]:
	var result: Array[PlayerCharacterData] = []
	for id in _order:
		result.append(_roster[id])
	return result

func is_registered(id: StringName) -> bool:
	return _roster.has(id)


# ─────────────────────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────────────────────

func _register_internal(data: PlayerCharacterData) -> void:
	if data == null:
		push_error("[CharacterManagement] Tentativa de registrar PlayerCharacterData null.")
		return
	var id: StringName = data.character_id
	if id.is_empty():
		push_error("[CharacterManagement] PlayerCharacterData sem character_id: '%s'" % data.display_name)
		return
	if _roster.has(id):
		return  # já no roster — sem duplicata
	_roster[id] = data
	_order.append(id)
	print("[CharacterManagement] No roster: '%s'" % id)


## Mantém GameManager.current_player sincronizado.
## GameManager.current_player é String "X" / "Zero" — usado por ArmorManager
## e outros sistemas legados. StringName → String é automático em GDScript.
func _sync_game_manager() -> void:
	GameManager.current_player = String(_active_id)
