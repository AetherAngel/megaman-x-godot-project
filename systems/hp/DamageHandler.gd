# systems/hp/DamageHandler.gd
class_name DamageHandler
extends Node

## Ponto único de entrada para qualquer dano externo a um Actor.
##
## Responsabilidades:
##   1. Receber dano + tipo de dano de qualquer fonte externa
##   2. Resolver o dano final via DamageResistanceTable (se existir)
##   3. Aplicar redução de armadura (se Actor for Player)
##   4. Rotear para HPSystem.apply_damage()
##   5. Emitir Actor.damaged
##   6. Iniciar I-Frames via Actor.invulnerability
##
## Responsabilidades futuras (sem refatoração):
##   - Checar tipos especiais de dano (absorção, reflexão)
##   - Efeitos visuais por tipo (flash de cor por elemento)

# ── Referências ───────────────────────────────────────────────
var _hp_system: HPSystem
var _actor: Actor

## Tabela de resistência deste Actor. Configurada no editor.
## Boss: arraste o .tres de DamageResistanceTable específico do boss.
## Player / Inimigo simples: deixe null (sem resolução por tipo).
@export var resistance_table: DamageResistanceTable


# ─────────────────────────────────────────────────────────────
# GODOT
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_actor = get_parent() as Actor
	if not _actor:
		push_error("[DamageHandler] Owner não é um Actor: '%s'" % get_parent().name)
		return

	_hp_system = _actor.get_node_or_null("HPSystem") as HPSystem
	if not _hp_system:
		push_error("[DamageHandler] HPSystem não encontrado em: '%s'" % _actor.name)


# ─────────────────────────────────────────────────────────────
# API PÚBLICA
# ─────────────────────────────────────────────────────────────

## Ponto de entrada principal para qualquer fonte de dano.
##
## raw_value    : dano em unidades (float aceito — convertido a int via ceili).
## damage_type_id: tipo do dano. Use DamageType.FIRE, DamageType.BUSTER, etc.
##                 Fontes sem tipo definido passam DamageType.CONTACT.
## inflicter    : quem causou o dano. Pode ser null.
##
## NOTA: verificações de invulnerabilidade (I-Frames, toggleable) devem ser
## feitas ANTES de chamar receive() — em Player.take_damage() / Boss.take_damage().
## DamageHandler assume que o dano chegando é válido.
func receive(raw_value: float, damage_type_id: StringName, inflicter = null) -> void:
	if not _hp_system:
		return
	if raw_value <= 0.0:
		return

	var raw_units := ceili(raw_value)

	# 1. Resolução por tipo de dano (DamageResistanceTable do boss).
	var resolved_units: int = DamageTypeResolver.resolve(
		raw_units,
		damage_type_id,
		resistance_table
	)

	# 2. Imunidade — resultado 0 = imune, descarta silenciosamente.
	if resolved_units <= 0:
		return

	# 3. Redução de armadura (apenas Player com ArmorData configurada).
	var final_units := _apply_armor_reduction(resolved_units)

	# 4. Aplica dano no HPSystem.
	_hp_system.apply_damage(final_units)

	# 5. Propaga signal damaged do Actor para states (Hit, Stagger).
	_actor.damaged.emit(float(final_units), inflicter)

	# 6. I-Frames — inicia invulnerabilidade no Actor.
	# Duração configurada em HPSystemData.i_frame_duration por tipo de Actor.
	_apply_i_frames()


# ─────────────────────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────────────────────

## Aplica damage_reduction da armadura equipada (Player).
## Se o Actor não tem current_armor ou damage_reduction = 0.0, retorna intacto.
func _apply_armor_reduction(units: int) -> int:
	# Verifica se o Actor pai tem current_armor (é um Player com armadura).
	# Usa duck typing — sem acoplamento direto à classe Player.
	if not _actor.get(&"current_armor"):
		return units

	var armor: ArmorData = _actor.get(&"current_armor") as ArmorData
	if not armor or armor.damage_reduction <= 0.0:
		return units

	var reduced := float(units) * (1.0 - armor.damage_reduction)
	return maxi(1, ceili(reduced))  # mínimo 1 unidade — nunca zera por redução


## Inicia o timer de I-Frames no Actor.
## Duração vem de HPSystemData.i_frame_duration.
## 0.0 = sem I-Frames (inimigos simples).
func _apply_i_frames() -> void:
	if not _hp_system or not _hp_system.data:
		return
	var duration: float = _hp_system.data.i_frame_duration
	if duration <= 0.0:
		return
	# Actor.invulnerability já existe e é decrementado em _process_invulnerability().
	# Preserva o maior valor caso já esteja em I-Frame (hit durante I-Frame existente).
	_actor.invulnerability = maxf(_actor.invulnerability, duration)
