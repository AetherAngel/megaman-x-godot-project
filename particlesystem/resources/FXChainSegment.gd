class_name FXChainSegment
extends Node2D

## Um elo de uma cadeia segmentada (ver FXChainDef). Persegue exclusivamente
## o Node2D indicado em `leader` — nunca uma posição fixa no mundo.
##
## Funciona gravando, a cada frame, a posição atual de `leader` num
## histórico próprio, e se posicionando onde `leader` estava `delay`
## segundos atrás (não onde ele está agora) — como um replay levemente
## atrasado. Isso vale tanto se `leader` é um objeto de gameplay de
## verdade (a cabeça da cadeia) quanto se é outro FXChainSegment (o elo
## anterior) — o mecanismo é idêntico nos dois casos. É isso que permite
## a cadeia (e, no futuro, ramificações) sem precisar de casos especiais.
##
## A cadeia cresce em cascata: este segmento emite ready_to_spawn_next
## quando atinge seu próprio gatilho de criação (ver
## FXChainSegmentBehavior.spawn_next_on_loop/spawn_next_at, ou por tempo
## fixo se não configurado) — é o FXChainController quem escuta esse
## sinal e cria o próximo elo.
##
## A POSIÇÃO é sempre calculada, desde o instante em que o segmento
## nasce — nunca fica "esperando" pra começar a seguir. A VISIBILIDADE é
## um controle totalmente separado (ver FXChainSegmentBehavior) e não
## tem nenhuma relação com quando o próximo elo é criado.

signal ready_to_spawn_next
signal leader_disappeared

var leader:            Node2D  = null
var delay:             float   = 0.08  # atraso de POSIÇÃO (espaçamento) — FXChainDef.segment_interval
var spawn_next_delay:  float   = 0.1   # ritmo de CRIAÇÃO do próximo, fallback por tempo — FXChainDef.spawn_interval
var body_offset:       Vector2 = Vector2.ZERO  # offset da cadeia inteira (FXChainDef.body_offset)

var _def:      FXChainSegmentDef      = null
var _visual:   FXChainSegmentVisual   = null  # personalização opcional deste segmento (frame/loop/offset/z_index/flip)
var _behavior: FXChainSegmentBehavior = null  # gatilho de criação do próximo + visibilidade/vida opcionais
var _sprite:   AnimatedSprite2D       = null
var _history:  Array                  = []  # [{t: float, pos: Vector2}, ...] posições do leader ao longo do tempo
var _elapsed:  float                  = 0.0

var _loop_elapsed: float = 0.0  # tempo acumulado desde a criação — driva o loop_frames visual, o toggle de visibilidade E o gatilho de criação do próximo

var _spawned_next: bool = false  # já emitiu ready_to_spawn_next uma vez (só emite uma vez, sempre)
var _facing_mirrored: bool = false  # true quando a cabeça diverge da orientação nativa — espelha offset.x

# ── Estado do toggle de visibilidade (cosmético, independente do spawn) ──
var _last_watch_progress:   float = 0.0
var _last_watch_loop_count: int   = 0
var _toggled_once:          bool  = false
var _leader_disappearance_reported: bool = false
# Movimento após o desaparecimento do leader.
var _last_leader_velocity: Vector2 = Vector2.ZERO
var _moving_without_leader: bool = false


func setup(
	def:                FXChainSegmentDef,
	p_leader:           Node2D,
	p_delay:            float,
	visual:             FXChainSegmentVisual = null,
	p_body_offset:      Vector2 = Vector2.ZERO,
	behavior:           FXChainSegmentBehavior = null,
	p_spawn_next_delay: float = 0.1
) -> void:
	_def         = def
	_visual      = visual
	_behavior    = behavior
	leader       = p_leader
	delay        = p_delay
	body_offset  = p_body_offset
	spawn_next_delay = p_spawn_next_delay
	_elapsed       = 0.0
	_loop_elapsed  = 0.0
	_spawned_next  = false
	_history.clear()

	if _visual:
		z_index = _visual.z_index
	elif def:
		z_index = def.z_index

	if def:
		scale = def.segment_scale

	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)
	if def and def.sprite_frames and def.sprite_frames.has_animation(def.animation):
		_sprite.sprite_frames = def.sprite_frames
		_sprite.animation     = def.animation

		if _visual and not _visual.loop_frames.is_empty():
			# Loop customizado — frames escolhidos à mão, ciclando na ordem dada.
			_sprite.stop()
			_sprite.frame = _visual.loop_frames[0]
		elif _visual and _visual.frame >= 0:
			# Frame fixo — trava aqui, não anima.
			_sprite.stop()
			_sprite.frame = _visual.frame
		else:
			_sprite.play(def.animation)
			_sprite.frame = 0  # força o início de verdade — o Godot não reseta
							   # o frame relativo a esta chamada de .play().

	visible = _behavior.start_visible if _behavior else true


func _process(delta: float) -> void:
	_update_loop_frame(delta)
	_elapsed += delta

	# Vida máxima (rede de segurança) — verificada antes de qualquer coisa,
	# funciona mesmo se o leader já sumiu e este segmento está congelado.
	if _behavior and _behavior.max_lifetime > 0.0 and _elapsed >= _behavior.max_lifetime:
		remove_segment()
		return

	_check_spawn_next()
	_update_visibility_toggle()

	if not is_instance_valid(leader):
		# O leader sumiu (ex: a cabeça atingiu algo). Não me destruo sozinho —
		# só congelo aqui. Quem decide quando eu realmente sumo é o
		# FXChainController, via remove_segment(), no momento certo do dominó
		# (ou o max_lifetime acima, se configurado).
		if not _leader_disappearance_reported:
			_leader_disappearance_reported = true
			leader_disappeared.emit()

		# Sem a opção explicitamente habilitada, mantém o comportamento
		# original: o segmento congela e aguarda a regra de destruição
		# existente, como o dominó ou max_lifetime.
		if not (_behavior and _behavior.continue_moving_after_leader_disappears):
			return

		# A transição acontece uma única vez. A posição atual do segmento
		# é preservada como origem do movimento independente; não usamos
		# o histórico para reposicioná-lo após a perda do leader.
		_moving_without_leader = true

		# Sem velocidade observável, não inventamos movimento.
		if _last_leader_velocity.length_squared() <= 0.0001:
			return

		# Continua a trajetória usando a última velocidade não nula
		# registrada enquanto o leader ainda existia.
		global_position += _last_leader_velocity * delta
		return

	_history.append({"t": _elapsed, "pos": leader.global_position})
	_update_last_leader_velocity()
	_trim_history()

	# Se nasceu invisível e nada mais controla a visibilidade dele, revela
	# sozinho assim que a posição já tiver histórico suficiente pra ser
	# confiável (delay segundos) — evita o efeito de "correr atrás" à
	# mostra: ele só aparece quando já está no lugar certo.
	if not visible and not (_behavior and _behavior.toggle_visibility):
		if _elapsed >= delay:
			visible = true

	# Posição sempre atualizada, incondicional — não depende de visibilidade.
	# offset.x/body_offset.x são medidos na orientação NATIVA (o sprite
	# desenhado olhando pra um lado só) — espelha quando a cabeça diverge
	# disso, mesma lógica que Boss._spawn_object() já usa pro offset dela.
	var offset := _visual.offset if _visual else Vector2.ZERO
	var final_offset := body_offset + offset
	if _facing_mirrored:
		final_offset.x = -final_offset.x
	global_position = _sample_position(_elapsed - delay) + final_offset


## Decide QUANDO este segmento manda criar o próximo elo da cadeia.
## Só emite ready_to_spawn_next UMA VEZ na vida deste segmento.
func _check_spawn_next() -> void:
	if _spawned_next:
		return

	var ready: bool = false
	if _behavior and _behavior.spawn_next_on_loop:
		match _behavior.spawn_next_at:
			FXChainSegmentBehavior.LoopPoint.HALF:
				ready = get_loop_progress() >= 0.5
			_:  # START e END — ambos disparam quando ESTE segmento fecha um loop
				ready = get_loop_count() >= 1
	else:
		# Padrão: tempo fixo, independente do espaçamento visual — FXChainDef.spawn_interval.
		ready = _elapsed >= spawn_next_delay

	if ready:
		_spawned_next = true
		ready_to_spawn_next.emit()


func _update_loop_frame(delta: float) -> void:
	if not _sprite or not _visual or _visual.loop_frames.is_empty():
		return
	_loop_elapsed += delta
	var interval := maxf(_visual.loop_frame_interval, 0.001)
	var count := _visual.loop_frames.size()
	_sprite.frame = _visual.loop_frames[int(_loop_elapsed / interval) % count]


func _update_visibility_toggle() -> void:
	if not _behavior or not _behavior.toggle_visibility:
		return
	if not _behavior.related_to_previous or not is_instance_valid(leader) or not (leader is FXChainSegment):
		return
	if _toggled_once and not _behavior.continuous_toggle:
		return

	var prev := leader as FXChainSegment
	var crossed := false

	match _behavior.loop_point:
		FXChainSegmentBehavior.LoopPoint.HALF:
			var progress := prev.get_loop_progress()
			crossed = progress >= 0.5 and _last_watch_progress < 0.5
			_last_watch_progress = progress
		_:  # START e END — ambos disparam quando o anterior fecha um loop
			var count := prev.get_loop_count()
			crossed = count > _last_watch_loop_count
			_last_watch_loop_count = count

	if crossed:
		visible = not visible
		_toggled_once = true


func _trim_history() -> void:
	# Mantém só o suficiente pro atraso configurado, com uma margem de folga.
	var cutoff := _elapsed - delay - 0.5
	while _history.size() > 1 and _history[1]["t"] < cutoff:
		_history.pop_front()


func _sample_position(target_time: float) -> Vector2:
	var n := _history.size()
	if n == 0:
		return global_position
	if target_time <= _history[0]["t"]:
		return _history[0]["pos"]
	if target_time >= _history[n - 1]["t"]:
		return _history[n - 1]["pos"]

	for i in range(n - 1):
		var a: Dictionary = _history[i]
		var b: Dictionary = _history[i + 1]
		if a["t"] <= target_time and target_time <= b["t"]:
			var span: float = b["t"] - a["t"]
			var f: float = 0.0 if span <= 0.0 else (target_time - a["t"]) / span
			return (a["pos"] as Vector2).lerp(b["pos"], f)

	return _history[n - 1]["pos"]


# ── API pública usada por quem vem depois na cadeia / pelo controller ──

func _get_cycle_duration() -> float:
	if _visual and not _visual.loop_frames.is_empty():
		return maxf(_visual.loop_frame_interval, 0.001) * _visual.loop_frames.size()
	if _visual and _visual.frame >= 0:
		return 0.0
	if _sprite and _sprite.sprite_frames and _sprite.animation != &"":
		var frame_count := _sprite.sprite_frames.get_frame_count(_sprite.animation)
		var speed := _sprite.sprite_frames.get_animation_speed(_sprite.animation)
		if speed > 0.0:
			return float(frame_count) / speed
	return 0.0


## Progresso (0.0–1.0) do loop atual deste segmento. Usado pelo próprio
## gatilho de criação (spawn_next_at = HALF) e pelo toggle de
## visibilidade do próximo segmento (loop_point = HALF).
func get_loop_progress() -> float:
	var cycle := _get_cycle_duration()
	if cycle <= 0.0:
		return 1.0  # sem loop de verdade (frame fixo) — nunca trava quem depende disso
	return fmod(_loop_elapsed, cycle) / cycle


## Quantos loops este segmento já completou desde que nasceu. Usado pelo
## próprio gatilho de criação (spawn_next_at = START/END) e pelo toggle
## de visibilidade do próximo segmento.
func get_loop_count() -> int:
	var cycle := _get_cycle_duration()
	if cycle <= 0.0:
		return 1
	return int(_loop_elapsed / cycle)


## Aplica o flip horizontal e registra o resultado para diagnóstico.
## Remova os prints após confirmar se o valor chega corretamente.
func set_flip(flip_h: bool) -> void:
	if not is_instance_valid(_sprite):
		return

	_sprite.flip_h = not flip_h


## Espelha offset.x/body_offset.x quando a cabeça diverge da orientação
## nativa. Chamado pelo FXChainController sempre que flip_mode != NONE —
## independente de este segmento específico ter o sprite flipando ou não
## (isso é posição, não aparência).
func set_facing_mirrored(mirrored: bool) -> void:
	_facing_mirrored = mirrored


## Direção de movimento observada de `leader` recentemente — positivo =
## indo pra direita, negativo = indo pra esquerda, 0 = parado ou sem
## dados suficientes ainda. Usado pra descobrir a direção real da cabeça
## sem depender de nenhuma propriedade tipo "facing_right" nela (ela
## pode nem ter uma).
func get_movement_direction() -> float:
	if _history.size() < 2:
		return 0.0
	return _history[_history.size() - 1]["pos"].x - _history[0]["pos"].x


## Remove este segmento de verdade. Chamado pelo FXChainController no
## efeito dominó (ou pelo próprio segmento, via max_lifetime).
func remove_segment() -> void:
	queue_free()




func _update_last_leader_velocity() -> void:
	if _history.size() < 2:
		return

	var previous: Dictionary = _history[_history.size() - 2]
	var latest: Dictionary = _history[_history.size() - 1]

	var elapsed_time: float = latest["t"] - previous["t"]
	if elapsed_time <= 0.0001:
		return

	var displacement: Vector2 = latest["pos"] - previous["pos"]

	# Só atualiza quando existe movimento observável.
	# Se o leader parar, preservamos a última velocidade não nula.
	if displacement.length_squared() > 0.0001:
		_last_leader_velocity = displacement / elapsed_time
