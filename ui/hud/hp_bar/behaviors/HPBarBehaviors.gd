# ui/hud/hp_bar/behaviors/HPBarBehaviors.gd
#
# Todos os behaviors da HPBar em um arquivo.
# São RefCounted — leves, sem scene tree, sem signals.
# HPStateHandler os instancia e gerencia.
#
# Interface de cada behavior:
#   enter(bar: HPBar) → void   — executado ao entrar no estado
#   exit(bar: HPBar)  → void   — executado ao sair do estado
#   process(delta: float, bar: HPBar) → bool  — true = behavior concluído


# ═══════════════════════════════════════════════════════════════
# IDLE — estado neutro, aguarda próxima transição
# ═══════════════════════════════════════════════════════════════
class HPIdleBehavior extends RefCounted:

	func enter(_bar) -> void:
		pass  # nada a fazer no idle

	func exit(_bar) -> void:
		pass

	func process(_delta: float, _bar) -> bool:
		return false  # nunca conclui por conta própria — aguarda evento externo


# ═══════════════════════════════════════════════════════════════
# DAMAGE — esconde units do topo para baixo, uma por frame
# ═══════════════════════════════════════════════════════════════
class HPDamageBehavior extends RefCounted:

	## Unidades que ainda precisam ser escondidas.
	var _pending: int = 0
	## Acumulador de tempo entre cada unit (segundos entre remoções visuais).
	var _timer: float = 0.0
	## Intervalo entre cada unit removida visualmente.
	const INTERVAL: float = 0.04  # ~25 units/segundo — rápido como no MMX original

	func enter(_bar) -> void:
		_timer = 0.0

	func exit(_bar) -> void:
		pass

	## Informa quantas unidades serão retiradas antes de enter().
	## Chamado por HPStateHandler.transition_to(DAMAGE, amount).
	func set_pending(amount: int) -> void:
		_pending = amount

	func process(delta: float, bar) -> bool:
		if _pending <= 0:
			return true  # concluído

		_timer -= delta
		if _timer > 0.0:
			return false

		_timer = INTERVAL
		bar.hide_top_unit()
		_pending -= 1
		return _pending <= 0


# ═══════════════════════════════════════════════════════════════
# HEAL — mostra units de baixo para cima, uma por frame
# ═══════════════════════════════════════════════════════════════
class HPHealBehavior extends RefCounted:

	var _pending: int = 0
	var _timer: float = 0.0
	const INTERVAL: float = 0.04

	func enter(_bar) -> void:
		_timer = 0.0

	func exit(_bar) -> void:
		pass

	func set_pending(amount: int) -> void:
		_pending = amount

	func process(delta: float, bar) -> bool:
		if _pending <= 0:
			return true

		_timer -= delta
		if _timer > 0.0:
			return false

		_timer = INTERVAL
		bar.show_next_unit()
		_pending -= 1
		return _pending <= 0


# ═══════════════════════════════════════════════════════════════
# INCREASE — expande o max_units visível (HeartTank)
# Mostra as novas units acima das atuais, uma por frame
# ═══════════════════════════════════════════════════════════════
class HPIncreaseBehavior extends RefCounted:

	## Novas unidades de max a exibir (o current já foi atualizado pelo HPSystem).
	var _pending: int = 0
	var _timer: float = 0.0
	const INTERVAL: float = 0.06  # ligeiramente mais lento — efeito distinto da cura

	func enter(_bar) -> void:
		_timer = 0.0

	func exit(_bar) -> void:
		pass

	func set_pending(amount: int) -> void:
		_pending = amount

	func process(delta: float, bar) -> bool:
		if _pending <= 0:
			return true

		_timer -= delta
		if _timer > 0.0:
			return false

		_timer = INTERVAL
		bar.show_next_unit()
		_pending -= 1
		return _pending <= 0


# ═══════════════════════════════════════════════════════════════
# BOSS FILL — preenche a barra do boss durante BOSS_PRESENTATION
# Quando completo, chama GameManager.on_boss_presentation_complete()
# ═══════════════════════════════════════════════════════════════
class BossHPBehavior extends RefCounted:

	## Velocidade em unidades/segundo. Vem de HPBarConfig.boss_fill_speed.
	var fill_speed: float = 16.0
	## Unidades já mostradas durante o fill.
	var _filled: int = 0
	## Total a preencher.
	var _target: int = 0
	## Acumulador fracionário para velocidade sub-frame.
	var _accumulator: float = 0.0

	func enter(bar) -> void:
		_filled      = 0
		_accumulator = 0.0
		_target      = bar.max_units
		# Garante que a barra começa vazia visualmente.
		bar.force_show_units(0)

	func exit(_bar) -> void:
		pass

	func process(delta: float, bar) -> bool:
		# Segurança: se por algum motivo process() for chamado já concluído
		# (não deveria acontecer, já que exit() troca o behavior), não refaz
		# o preenchimento nem rechama o callback de conclusão.
		if _filled >= _target:
			return true

		_accumulator += fill_speed * delta
		var to_show := int(_accumulator)
		if to_show > 0:
			_accumulator -= float(to_show)
			for i in to_show:
				if _filled >= _target:
					break
				bar.show_next_unit()
				_filled += 1

		# ÚNICO ponto de saída "concluído": garante que o callback dispara
		# exatamente na mesma chamada em que _filled atinge _target, antes
		# de sinalizar "true" pro HPStateHandler (que troca o behavior
		# imediatamente e nunca chama process() de novo nesta instância).
		if _filled >= _target:
			GameManager.on_boss_presentation_complete()
			return true

		return false
