# systems/hp/HealHandler.gd
class_name HealHandler
extends Node

## Processa todas as formas de recuperação de HP de um Actor.
##
## Tipos de cura suportados:
##   heal(units)      → SmallHealth (+2), LargeHealth (+8), cura parcial genérica
##   full_heal()      → SubTank (enche o HP atual ao máximo — reutilizável)
##   increase_max()   → HeartTank (aumenta o HP máximo permanentemente)
##
## Responsabilidade futura (sem refatoração):
##   - Checar se o personagem está com HP cheio antes de consumir item
##   - Efeito visual/sonoro de cura (pode emitir signal aqui)
##   - Overflow para SubTank quando HP já está cheio


# ─────────────────────────────────────────────────────────────
# REFERÊNCIAS INTERNAS
# ─────────────────────────────────────────────────────────────

var _hp_system: HPSystem
var _actor: Actor


# ─────────────────────────────────────────────────────────────
# GODOT
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_actor = get_parent() as Actor
	if not _actor:
		push_error("[HealHandler] Owner não é um Actor: '%s'" % get_parent().name)
		return

	_hp_system = _actor.get_node_or_null("HPSystem") as HPSystem
	if not _hp_system:
		push_error("[HealHandler] HPSystem não encontrado em: '%s'" % _actor.name)


# ─────────────────────────────────────────────────────────────
# API PÚBLICA
# ─────────────────────────────────────────────────────────────

## Cura parcial — SmallHealth (+2 unidades) ou LargeHealth (+8 unidades).
## Também usado por qualquer outra fonte de cura com valor fixo.
func heal(units: int) -> void:
	if not _hp_system:
		return
	if units <= 0:
		return
	_hp_system.apply_heal(units)


## Cura total — SubTank.
## Enche o HP atual ao máximo. O SubTank em si controla quantas vezes pode ser usado.
func full_heal() -> void:
	if not _hp_system:
		return
	_hp_system.apply_full_heal()


## Aumento permanente de HP máximo — HeartTank.
## Incrementa max_units pelo bônus configurado em HPSystemData.heart_tank_bonus.
## Também cura o personagem pelo mesmo valor ganho (comportamento original do MMX).
##
## Chamado pelo HeartTank ao ser coletado:
##   player.heal_handler.increase_max()
func increase_max() -> void:
	if not _hp_system or not _hp_system.data:
		return
	_hp_system.apply_increase(_hp_system.data.heart_tank_bonus)


## True se o HP atual já está no máximo — útil para checar antes de consumir item.
func is_full() -> bool:
	if not _hp_system:
		return true
	return _hp_system.current_units >= _hp_system.max_units
