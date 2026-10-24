# systems/bt/actions/BossAction.gd
class_name BossAction
extends Resource

## Classe base para qualquer ação de Boss ou NPC.
## Define COMO uma ação acontece — animações, movimento, hitboxes, FX.
## A BT define QUANDO ela é usada.
##
## Cada ação específica cria um .gd que estende BossAction:
##   MagmaDragoonHadouken.gd
##   MagmaDragoonShoryuken.gd
##   MagmaDragoonChargeFire.gd
##
## Bug numa ação? Abre o .gd correspondente. Ponto final.
##
## Fases:
##   A ação executa AnimPhase[0], AnimPhase[1], ... em sequência.
##   Cada fase tem sua própria condição de saída (ON_FINISH, ON_TIMER, ON_SIGNAL).
##   Quando todas as fases terminam, a ação retorna true em update() → BTAction → SUCCESS.

@export var phases: Array[AnimPhase] = []

# ── Estado interno (seguro após duplicate(true)) ──────────────
var _phase_index:        int   = 0
var _phase_timer:        float = 0.0
var _signal_triggered:   bool  = false
var _last_checked_frame: int   = -1
var _fired_events:       Array[bool] = []
## Último objeto criado por um FrameEvent.SPAWN_OBJECT nesta execução da
## ação. Usado como "cabeça" quando um SPAWN_FX com fx_resource = FXChainDef
## dispara depois — configure o SPAWN_OBJECT antes na sequência de frames.
var _last_spawned_object: Node2D = null
## true enquanto esta ação mantém sua trava em actor.toggleable_invulnerabilities.
var _invuln_active: bool = false


# ─────────────────────────────────────────────────────────────
# CICLO DE VIDA — chamado pelo BTAction
# ─────────────────────────────────────────────────────────────

func start(actor: Node) -> void:
	_set_invulnerable(actor, false)  # nunca herda trava de uma execução anterior
	_phase_index      = 0
	_phase_timer      = 0.0
	_signal_triggered = false
	_last_checked_frame = -1
	_last_spawned_object = null
	actor.is_acting   = true
	if phases.is_empty():
		return
	_enter_phase(actor, phases[0])
	on_start(actor)


## Chamado a cada frame enquanto a ação está RUNNING.
## Retorna true quando todas as fases terminaram.
func update(actor: Node, delta: float) -> bool:
	if phases.is_empty():
		return true

	var phase: AnimPhase = phases[_phase_index]
	_phase_timer += delta

	_check_frame_events(actor, phase)

	if _should_advance(actor, phase):
		return _advance(actor)

	return false


func finish(actor: Node) -> void:
	_set_invulnerable(actor, false)
	actor.is_acting = false
	on_finish(actor)


# ─────────────────────────────────────────────────────────────
# HOOKS — override em subclasses para lógica específica do boss
# ─────────────────────────────────────────────────────────────

## Chamado no início da ação. Override para setup específico.
func on_start(_actor: Node) -> void:
	pass


## Chamado ao fim da ação. Override para cleanup específico.
func on_finish(_actor: Node) -> void:
	pass


## Chamado quando um FrameEvent do tipo HITBOX_ON ou HITBOX_OFF dispara.
## Override para conectar ao sistema de hitbox quando ele for implementado.
## event.value = nome do hitbox.
func _on_hitbox_event(_actor: Node, _event: FrameEvent) -> void:
	# TODO: conectar ao sistema de hitbox quando implementado.
	pass


# ─────────────────────────────────────────────────────────────
# CONTROLE DE FASE (ON_SIGNAL)
# ─────────────────────────────────────────────────────────────

## Avança a fase atual manualmente.
## Use para condições externas: FX terminou, player chegou à posição, etc.
## Chame de dentro de on_start() ou de um signal conectado no boss.
func advance_phase() -> void:
	_signal_triggered = true


# ─────────────────────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────────────────────

func _enter_phase(actor: Node, phase: AnimPhase) -> void:
	_phase_timer        = 0.0
	_signal_triggered   = false
	_last_checked_frame = -1
	_fired_events       = []
	_fired_events.resize(phase.frame_events.size())
	_fired_events.fill(false)
	_set_invulnerable(actor, phase.invulnerable)
	actor.set_visual_state(phase.anim_name)


## Liga/desliga a trava de invulnerabilidade desta ação no ator.
## A própria ação (Resource) é o token: duas fontes de invulnerabilidade nunca
## se confundem, e a trava some exatamente com quem a criou.
func _set_invulnerable(actor: Node, enabled: bool) -> void:
	if enabled == _invuln_active:
		return
	if not "toggleable_invulnerabilities" in actor:
		return
	_invuln_active = enabled
	if enabled:
		actor.toggleable_invulnerabilities.append(self)
	else:
		actor.toggleable_invulnerabilities.erase(self)


func _should_advance(_actor: Node, phase: AnimPhase) -> bool:
	match phase.exit:
		AnimPhase.ExitOn.ON_FINISH:
			# AnimatedSprite2D para de tocar ao fim de animações sem loop.
			var sprite := _actor.get_node_or_null("Sprite") as AnimatedSprite2D
			return sprite != null and not sprite.is_playing()

		AnimPhase.ExitOn.ON_TIMER:
			return _phase_timer >= phase.exit_timer

		AnimPhase.ExitOn.ON_SIGNAL:
			if _signal_triggered:
				return true
			# Proteção: não trava para sempre.
			if _phase_timer >= phase.signal_timeout:
				push_warning("[BossAction] ON_SIGNAL timeout em fase %d (%.1fs). Avançando forçado." \
					% [_phase_index, phase.signal_timeout])
				return true

	return false


func _advance(actor: Node) -> bool:
	_phase_index += 1
	if _phase_index >= phases.size():
		return true  # todas as fases terminaram — ação concluída
	_enter_phase(actor, phases[_phase_index])
	return false


func _check_frame_events(actor: Node, phase: AnimPhase) -> void:
	if phase.frame_events.is_empty():
		return

	var sprite := actor.get_node_or_null("Sprite") as AnimatedSprite2D
	if not sprite:
		return

	var current_frame := sprite.frame
	# Evita disparar o mesmo frame múltiplas vezes (animação corre a ~12fps, jogo a 60fps).
	if current_frame == _last_checked_frame:
		return
	_last_checked_frame = current_frame

	for i in phase.frame_events.size():
		if _fired_events[i]:
			continue
		var event: FrameEvent = phase.frame_events[i]
		if event.frame == current_frame:
			_fired_events[i] = true
			_dispatch_event(actor, event)


func _dispatch_event(actor: Node, event: FrameEvent) -> void:
	match event.type:
		FrameEvent.Type.HITBOX_ON, FrameEvent.Type.HITBOX_OFF:
			_on_hitbox_event(actor, event)

		FrameEvent.Type.SPAWN_FX:
			if actor is Node2D:
				_dispatch_spawn_fx(actor, event)

		FrameEvent.Type.PLAY_SFX:
			SoundManager.play_sfx(event.value)

		FrameEvent.Type.SPAWN_OBJECT:
			if event.spawn_object and actor.has_method("spawn_object"):
				_last_spawned_object = actor.spawn_object(event.spawn_object)
			elif not event.spawn_object:
				push_warning("[BossAction] FrameEvent SPAWN_OBJECT sem spawn_object configurado.")


## Resolve um FrameEvent.SPAWN_FX: usa `fx_resource` (genérico) se estiver
## preenchido; senão cai no `particle_def` legado. Ver catálogo de tipos
## aceitos no comentário de fx_resource, em FrameEvent.gd.
func _dispatch_spawn_fx(actor: Node2D, event: FrameEvent) -> void:
	if event.fx_resource:
		if event.fx_resource is FXChainDef:
			if is_instance_valid(_last_spawned_object):
				var controller := ParticleFX.spawn_chain(event.fx_resource, _last_spawned_object)
				if controller:
					# Guarda a referência no próprio objeto cabeça, via meta —
					# não exige nada especial no script do Hadouken. Quem
					# detectar o hit (sistema de colisão, ainda por fazer)
					# chama: get_meta(&"fx_chain_controller").on_hit()
					_last_spawned_object.set_meta(&"fx_chain_controller", controller)
			else:
				push_warning("[BossAction] SPAWN_FX com FXChainDef mas nenhum objeto foi spawnado antes (falta um SPAWN_OBJECT anterior na sequência).")
		elif event.fx_resource is BarrageDef:
			# Saraivada em lanes. Ao terminar, avança a fase atual — use exit = ON_SIGNAL nesta
			# AnimPhase: a pose (e a invulnerabilidade) duram exatamente a saraivada.
			var barrage := BarrageController.start(event.fx_resource, actor)
			if barrage:
				barrage.finished.connect(advance_phase)
			else:
				advance_phase()  # não conseguiu iniciar: a fase não fica presa esperando o sinal
		else:
			push_warning("[BossAction] fx_resource com tipo não suportado: %s" % event.fx_resource.get_class())
		return

	if event.particle_def:
		# owner = actor: resolve marker_path (e mirror_marker_with_facing) em relação ao boss.
		ParticleFX.spawn_at(event.particle_def, actor.global_position, Vector2.ZERO, actor)
