class_name FXChainController
extends Node2D

## Orquestra uma cadeia definida por FXChainDef: cria os N segmentos,
## encadeia cada um pra seguir o segmento anterior (o Segmento 1 segue a
## cabeça, um Node2D externo), e comanda a destruição em dominó quando
## on_hit() é chamado.
##
## Criado por ParticleFX.spawn_chain(). Não sabe o que é a cabeça —
## Hadouken, dragão, chicote, corrente — só precisa de um Node2D válido
## com global_position. Isso é o que deixa o sistema genérico.

var _def:          FXChainDef            = null
var _head:         Node2D                = null
var _segments:      Array[FXChainSegment] = []  # [0] = mais perto da cabeça ... último = mais distante
var _chain_stopped: bool                  = false
var _flip_debug_logged: bool               = false  # loga o diagnóstico de facing_right só uma vez por cadeia

var _spawn_from_origin: bool = false

# Posição original da cadeia, capturada antes de qualquer spawn_delay.
var _origin_position: Vector2 = Vector2.ZERO

# Tempo decorrido desde a inicialização da cadeia.
var _chain_elapsed: float = 0.0

# Histórico da posição da cabeça, incluindo o período de spawn_delay.
var _head_history: Array[Dictionary] = []


func setup(def: FXChainDef, head: Node2D) -> void:
	_def = def
	_head = head

	if not _def or not _def.segment_def or not is_instance_valid(_head):
		queue_free()
		return

	_origin_position = _head.global_position
	_chain_elapsed = 0.0
	_head_history.clear()
	_head_history.append({
		"t": 0.0,
		"pos": _origin_position
	})

	if _def.spawn_delay > 0.0:
		await get_tree().create_timer(_def.spawn_delay).timeout
		if not is_inside_tree():
			return

	_spawn_all_segments()


func _spawn_all_segments() -> void:
	if _chain_stopped or not is_instance_valid(_head):
		return
	_spawn_segment(0, _head)


## Cria UM segmento (índice `index`), seguindo `leader`. Se não for o
## último da cadeia, escuta o ready_to_spawn_next dele pra criar o
## próximo — é isso que faz a cauda crescer em cascata, um elo de cada
## vez, em vez de todos de uma vez.

func _spawn_segment(index: int, leader: Node2D) -> void:
	if _chain_stopped or index >= _def.segment_count:
		return

	var visual: FXChainSegmentVisual = null
	if index < _def.segment_visuals.size():
		visual = _def.segment_visuals[index]

	var behavior: FXChainSegmentBehavior = null
	if index < _def.segment_behaviors.size():
		behavior = _def.segment_behaviors[index]

	var segment := FXChainSegment.new()
	add_child(segment)

	if _def.spawn_from_origin:
		var leader_history: Array[Dictionary] = []

		if leader is FXChainSegment:
			leader_history = leader.get_position_history()
		else:
			leader_history = _head_history

		segment.setup(
			_def.segment_def,
			leader,
			_def.segment_interval,
			visual,
			_def.body_offset,
			behavior,
			_def.spawn_interval,
			true,
			_origin_position,
			_chain_elapsed,
			leader_history
		)
	else:
		segment.setup(
			_def.segment_def,
			leader,
			_def.segment_interval,
			visual,
			_def.body_offset,
			behavior,
			_def.spawn_interval
		)

	_segments.append(segment)

	# Só o primeiro segmento segue a cabeça original.
	if index == 0:
		segment.leader_disappeared.connect(_on_head_disappeared)

	if index + 1 < _def.segment_count:
		segment.ready_to_spawn_next.connect(
			_on_segment_ready_to_spawn_next.bind(segment, index + 1)
		)
		


func _on_segment_ready_to_spawn_next(source_segment: FXChainSegment, next_index: int) -> void:
	if _chain_stopped or not is_instance_valid(source_segment):
		return
	_spawn_segment(next_index, source_segment)


# ── Facing ────────────────────────────────────────────────────


func _process(delta: float) -> void:
	_chain_elapsed += delta

	if is_instance_valid(_head):
		_head_history.append({
			"t": _chain_elapsed,
			"pos": _head.global_position
		})

		# No modo spawn_from_origin, os segmentos precisam do
		# histórico completo para reconstruir a trajetória.
		if not _def.spawn_from_origin:
			var max_history_time: float = (
				_def.segment_interval * _def.segment_count + 1.0
			)
			var cutoff: float = _chain_elapsed - max_history_time

			while (
				_head_history.size() > 2
				and _head_history[1]["t"] < cutoff
			):
				_head_history.pop_front()

	_update_flip()




func _update_flip() -> void:
	if not _def or _def.flip_mode == FXChainDef.FlipMode.NONE:
		return
	if _segments.is_empty() or not is_instance_valid(_segments[0]):
		return

	var dir := _segments[0].get_movement_direction()
	if not _flip_debug_logged and absf(dir) >= 0.5:
		_flip_debug_logged = true
	if absf(dir) < 0.5:
		return  # ainda sem movimento real observável — não decide nada ainda

	var moving_right := dir > 0.0
	# Assume arte desenhada olhando pra direita por padrão. Se o seu
	# sprite for o contrário, inverte aqui.
	var flip_h: bool = moving_right
			

	for i in _segments.size():
		var segment := _segments[i]
		if not is_instance_valid(segment):
			continue

		# Espelha offset.x/body_offset.x sempre que a cabeça diverge da
		# orientação nativa — independente do sprite flipar ou não. Sem
		# isso, um offset pensado pra um lado (ex: cauda "atrás" do
		# Hadouken indo pra esquerda) fica incorreto quando ele nasce
		# indo pro outro lado.
		segment.set_facing_mirrored(flip_h)

		if _def.flip_mode == FXChainDef.FlipMode.ALL_FOLLOW_HEAD:
			segment.set_flip(flip_h)
		else:  # PER_SEGMENT
			var visual: FXChainSegmentVisual = _def.segment_visuals[i] if i < _def.segment_visuals.size() else null
			if visual and visual.flip_with_facing:
				segment.set_flip(flip_h)


# ── Destruição em dominó ─────────────────────────────────────

## Chamado externamente por quem detectar o hit (jogador ou parede).
## Não mexe na cabeça — quem chamou isso já deve ter cuidado dela por
## fora. Aqui só cuida dos segmentos que este controller gerencia.
func on_hit() -> void:
	if _chain_stopped:
		return
	_chain_stopped = true
	_run_domino()


## Destrói os segmentos em sequência, respeitando o intervalo configurado.
## A ordem pode ser invertida através de FXChainDef.domino_forward.
func _run_domino() -> void:
	var count: int = _segments.size()

	# Define o índice inicial, o limite e o sentido da iteração.
	var start: int = 0 if _def.domino_forward else count - 1
	var end: int = count if _def.domino_forward else -1
	var step: int = 1 if _def.domino_forward else -1

	for i in range(start, end, step):
		var segment := _segments[i]

		if is_instance_valid(segment):
			segment.remove_segment()

		# Aguarda entre remoções, mas não depois da última.
		if i != (end - step):
			await get_tree().create_timer(_def.domino_delay).timeout

			# Interrompe se o controlador sair da árvore durante a espera.
			if not is_inside_tree():
				return

	queue_free()



func _on_head_disappeared() -> void:
	if _chain_stopped or not _def:
		return

	var behavior: FXChainSegmentBehavior = null
	if not _def.segment_behaviors.is_empty():
		behavior = _def.segment_behaviors[0]

	if not behavior or not behavior.destroy_when_leader_disappears:
		return

	if _def.domino_delay > 0.0:
		on_hit()
		return

	_chain_stopped = true

	for segment in _segments:
		if is_instance_valid(segment):
			segment.remove_segment()

	queue_free()



func get_chain_elapsed() -> float:
	return _chain_elapsed
