# systems/hp/HPSystem.gd
class_name HPSystem
extends Node

## Sistema universal de HP. Adicionado como filho de qualquer Actor.
##
## DOIS MODOS:
##   is_player_bound = true  → Player. character_id e data são resolvidos
##     DINAMICAMENTE via CharacterManagement a cada troca de personagem.
##     O mesmo node HPSystem (único, vive no Player.tscn) serve qualquer
##     personagem que estiver ativo no momento.
##
##   is_player_bound = false (default) → Boss/NPC. character_id fica vazio,
##     `data` é atribuído direto no Inspector, exatamente como sempre foi.
##     HP é efêmero — não usa HPRegistry, não persiste entre cenas.

@export var data: HPSystemData
@export var character_id: StringName = &""

## Marque true SOMENTE no HPSystem do Player.tscn.
## Faz character_id e data serem resolvidos dinamicamente via
## CharacterManagement a cada character_switched — necessário porque o
## Player é um único node reaproveitado entre X, Zero, Axl etc.
@export var is_player_bound: bool = false

var current_units: int = 0
var max_units: int     = 0
var remaining_segments: int = 1
var _actor: Actor

signal units_changed(current: int, maximum: int)
signal segment_depleted(remaining: int)
signal depleted()


func _ready() -> void:
	_actor = get_parent() as Actor
	if not _actor:
		push_error("[HPSystem] Owner não é um Actor: '%s'" % get_parent().name)
		return

	add_to_group("hp_systems")

	if is_player_bound:
		character_id = CharacterManagement.get_active_id()
		data = _resolve_player_hp_data(character_id)
		CharacterManagement.character_pre_switch.connect(_on_character_pre_switch)
		CharacterManagement.character_switched.connect(_on_character_switched)

	if not data:
		push_error("[HPSystem] HPSystemData não configurado em: '%s'" % _actor.name)
		return

	_initialize()


# ─────────────────────────────────────────────────────────────
# LOCK / UNLOCK — usados pelo CombatLockManager
# ─────────────────────────────────────────────────────────────

func lock(reason: StringName) -> void:
	if not _actor:
		return
	if not _actor.toggleable_invulnerabilities.has(reason):
		_actor.toggleable_invulnerabilities.append(reason)


func unlock(reason: StringName) -> void:
	if not _actor:
		return
	_actor.toggleable_invulnerabilities.erase(reason)


func is_locked() -> bool:
	if not _actor:
		return false
	return not _actor.toggleable_invulnerabilities.is_empty()


# ─────────────────────────────────────────────────────────────
# RESOLUÇÃO DINÂMICA (apenas player)
# ─────────────────────────────────────────────────────────────

## Busca a HPSystemData diretamente da ficha do personagem.
## Cada PlayerCharacterData (x_character.tres, zero_character.tres)
## carrega sua própria hp_data — sem isso, todos os personagens
## compartilhariam a mesma configuração fixa (o bug original).
func _resolve_player_hp_data(id: StringName) -> HPSystemData:
	var char_data: PlayerCharacterData = CharacterManagement.get_data(id)
	if not char_data:
		push_error("[HPSystem] CharacterManagement sem ficha para '%s'" % id)
		return null
	if not char_data.hp_data:
		push_error("[HPSystem] Ficha de '%s' sem hp_data configurado." % id)
		return null
	return char_data.hp_data


# ─────────────────────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────────────────────

func _initialize() -> void:
	remaining_segments = data.max_segments

	if not character_id.is_empty():
		HPRegistry.register(character_id, data.base_max_units)
		var snap := HPRegistry.get_snapshot(character_id)
		if snap:
			current_units = snap.current_units
			max_units     = snap.max_units
	else:
		max_units     = data.base_max_units
		current_units = max_units

	_sync_actor()
	units_changed.emit(current_units, max_units)


# ─────────────────────────────────────────────────────────────
# PROPRIEDADES CALCULADAS
# ─────────────────────────────────────────────────────────────

var hp_ratio: float:
	get: return float(current_units) / float(max_units) if max_units > 0 else 0.0

func is_depleted() -> bool:
	return current_units <= 0 and remaining_segments <= 1


# ─────────────────────────────────────────────────────────────
# API PÚBLICA
# ─────────────────────────────────────────────────────────────

func apply_damage(units: int) -> void:
	if units <= 0:
		return
	current_units = maxi(0, current_units - units)
	_sync_actor()
	units_changed.emit(current_units, max_units)
	if current_units <= 0:
		if remaining_segments > 1:
			remaining_segments -= 1
			current_units = max_units
			_sync_actor()
			segment_depleted.emit(remaining_segments)
			units_changed.emit(current_units, max_units)
		else:
			depleted.emit()


func apply_heal(units: int) -> void:
	if units <= 0:
		return
	current_units = mini(max_units, current_units + units)
	_sync_actor()
	units_changed.emit(current_units, max_units)


func apply_full_heal() -> void:
	current_units = max_units
	_sync_actor()
	units_changed.emit(current_units, max_units)


func apply_increase(bonus: int) -> void:
	var new_max := mini(data.unit_cap, max_units + bonus)
	var gained  := new_max - max_units
	max_units     = new_max
	current_units = mini(max_units, current_units + gained)
	_sync_actor()
	units_changed.emit(current_units, max_units)


func debug_force_units(units: int) -> void:
	current_units = clampi(units, 0, max_units)
	_sync_actor()
	units_changed.emit(current_units, max_units)


# ─────────────────────────────────────────────────────────────
# REGISTRY — troca de personagem (apenas player, is_player_bound = true)
# ─────────────────────────────────────────────────────────────

## Salva o estado do personagem que está SAINDO, antes da troca.
func _on_character_pre_switch(old_id: StringName) -> void:
	if not is_player_bound:
		return
	if old_id != character_id:
		return
	HPRegistry.save_snapshot(character_id, current_units, max_units)


## Re-resolve character_id e data para o personagem que está ENTRANDO.
## Isso é o que faltava antes — sem isso, o HPSystem continuava preso
## ao primeiro personagem configurado no Inspector.
func _on_character_switched(new_id: StringName) -> void:
	if not is_player_bound:
		return

	character_id = new_id
	data = _resolve_player_hp_data(new_id)
	if not data:
		return

	remaining_segments = data.max_segments

	var snap := HPRegistry.get_snapshot(character_id)
	if snap:
		current_units = snap.current_units
		max_units     = snap.max_units
	else:
		# Primeira vez que este personagem é ativado nesta stage.
		HPRegistry.register(character_id, data.base_max_units)
		max_units     = data.base_max_units
		current_units = max_units

	_sync_actor()
	units_changed.emit(current_units, max_units)


# ─────────────────────────────────────────────────────────────
# SYNC COM ACTOR
# ─────────────────────────────────────────────────────────────

func _sync_actor() -> void:
	if not _actor:
		return
	_actor.current_health = float(current_units)
	_actor.max_health     = float(max_units)
