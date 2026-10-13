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


func setup(def: FXChainDef, head: Node2D) -> void:
	_def  = def
	_head = head

	if not _def or not _def.segment_def or not is_instance_valid(_head):
		queue_free()
		return

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
	segment.setup(_def.segment_def, leader, _def.segment_interval, visual, _def.body_offset, behavior, _def.spawn_interval)
	_segments.append(segment)

	if index + 1 < _def.segment_count:
		segment.ready_to_spawn_next.connect(_on_segment_ready_to_spawn_next.bind(segment, index + 1))


func _on_segment_ready_to_spawn_next(source_segment: FXChainSegment, next_index: int) -> void:
	if _chain_stopped or not is_instance_valid(source_segment):
		return
	_spawn_segment(next_index, source_segment)


# ── Facing ────────────────────────────────────────────────────

func _process(_delta: float) -> void:
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


func _run_domino() -> void:
	for i in range(_segments.size() - 1, -1, -1):
		var segment := _segments[i]
		if is_instance_valid(segment):
			segment.remove_segment()
		if i > 0:
			await get_tree().create_timer(_def.domino_delay).timeout
			if not is_inside_tree():
				return
	queue_free()
