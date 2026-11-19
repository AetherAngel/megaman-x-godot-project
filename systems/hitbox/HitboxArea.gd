# systems/hitbox/HitboxArea.gd
class_name HitboxArea
extends Area2D

## Executa uma HitboxDef: um retângulo de dano que nasce, cresce, segue o dono e some sozinho.
##
## Não conhece Boss, Player, FrameEvent nem ataque nenhum. O dono precisa ser só um Node2D;
## se tiver get_facing_flip(), a hitbox espelha com ele. Quem precisa de uma hitbox chama:
##
##     HitboxArea.spawn(def, dono, token, frame_source)   # nasce, filha do dono
##     HitboxArea.clear(dono, token, id)                  # remove (idempotente)
##
## O dano passa pelo pipeline de sempre: HitComponent.report() -> HitBus. Nada dele muda.
##
## SEM estado compartilhado: as hitboxes ativas são simplesmente filhas do dono (uma ação
## .tres compartilhada entre dois bosses nunca confunde as hitboxes de um com as do outro).
##
## TEMPO: o ciclo roda no _physics_process. A hitbox só pode expirar a partir do SEGUNDO tick
## de física: o primeiro é o que a coloca no mundo; os hits são entregues no início do tick
## seguinte, antes de qualquer _physics_process. Por isso nunca vive menos que 1 tick.

## Dono que pediu a hitbox (também é o pai do nó).
var owner_node: Node2D = null
## Identidade de quem a criou (instance id do token passado em spawn()). 0 = sem token.
var token_id: int = 0
var def: HitboxDef = null

var _frame_source: AnimatedSprite2D = null
var _last_frame: int = 0
var _last_anim: StringName = &""

var _shape: RectangleShape2D = null
var _col: CollisionShape2D = null
var _hit: HitComponent = null

var _steps: int = 0            # frames decorridos desde o nascimento
var _elapsed: float = 0.0
var _placed: bool = false      # o 1º tick (o que a coloca no mundo) já passou
var _expired: bool = false


# ─────────────────────────────────────────────────────────────
# API PÚBLICA
# ─────────────────────────────────────────────────────────────

## Cria a hitbox como filha de `owner`. Devolve null (com aviso) se a Def ou o dono forem
## inválidos. `token` identifica quem a pediu, para clear() (qualquer Object: uma ação,
## um State...). `frame_source`, se dado, faz "frame" significar frame de animação.
static func spawn(hitbox_def: HitboxDef, owner: Node2D, token: Object = null,
		frame_source: AnimatedSprite2D = null) -> HitboxArea:
	if hitbox_def == null:
		push_warning("HitboxArea.spawn: HitboxDef nula.")
		return null
	if hitbox_def.profile == null:
		push_warning("HitboxArea.spawn: HitboxDef '%s' sem DamageProfile." % hitbox_def.id)
		return null
	if not is_instance_valid(owner):
		push_warning("HitboxArea.spawn: dono inválido.")
		return null

	var area := HitboxArea.new()
	area._setup(hitbox_def, owner, token, frame_source)
	owner.add_child(area)
	return area


## Remove as hitboxes de `owner`. Sem token = todas; com token = só as dele; com id = só as
## com esse nome. Idempotente: chamar de novo (ou sem nada para remover) não faz mal.
## Devolve quantas removeu.
static func clear(owner: Node, token: Object = null, id: StringName = &"") -> int:
	if not is_instance_valid(owner):
		return 0
	var removed: int = 0
	var tid: int = token.get_instance_id() if token != null else 0
	for child in owner.get_children():
		var area := child as HitboxArea
		if area == null or area._expired:
			continue
		if token != null and area.token_id != tid:
			continue
		if id != &"" and area.def.id != id:
			continue
		area._expire()
		removed += 1
	return removed


## Quantas hitboxes vivas `owner` tem (com o filtro opcional de token).
static func count_active(owner: Node, token: Object = null) -> int:
	if not is_instance_valid(owner):
		return 0
	var n: int = 0
	var tid: int = token.get_instance_id() if token != null else 0
	for child in owner.get_children():
		var area := child as HitboxArea
		if area == null or area._expired:
			continue
		if token != null and area.token_id != tid:
			continue
		n += 1
	return n


## Esta hitbox está VIVA, é do dono `of_owner` e tem prioridade MAIOR que `other_priority`?
## (Primeira pergunta do HitComponent: "preciso esperar o fim do passo para decidir?")
func ranks_above(of_owner: Node, other_priority: int) -> bool:
	return not _expired and owner_node == of_owner and def.priority > other_priority


## ...e além disso JÁ está sobrepondo `target`? Só então ela ganha a disputa. Perguntado no
## fim do passo de física, quando as sobreposições de todas as áreas estão consistentes: é
## isso que torna a disputa simultânea e independente da ordem dos sinais.
## Chamado pelo HitComponent (duck typing, pelo grupo "hitbox_area").
func outranks(of_owner: Node, other_priority: int, target: Node) -> bool:
	if not ranks_above(of_owner, other_priority) or not monitoring:
		return false
	return is_instance_valid(target) and overlaps_body(target)


# ─────────────────────────────────────────────────────────────
# INTERNO
# ─────────────────────────────────────────────────────────────

func _setup(hitbox_def: HitboxDef, owner: Node2D, token: Object, frame_source: AnimatedSprite2D) -> void:
	def = hitbox_def
	owner_node = owner
	token_id = token.get_instance_id() if token != null else 0
	_frame_source = frame_source
	if is_instance_valid(_frame_source):
		_last_frame = _frame_source.frame
		_last_anim = _frame_source.animation

	name = "HitboxArea"
	add_to_group("hitbox_area")
	set_meta("hitbox_priority", def.priority)

	# Só detecta: não é detectada por ninguém.
	collision_layer = 0
	collision_mask = def.target_mask
	monitorable = false
	monitoring = true

	# Um RectangleShape2D por instância: Resources de shape são compartilhados por padrão.
	_shape = RectangleShape2D.new()
	_col = CollisionShape2D.new()
	_col.shape = _shape
	add_child(_col)

	# O HitComponent lê auto_report/report_mode no _ready: configurar ANTES de entrar na árvore.
	_hit = HitComponent.new()
	_hit.name = "HitComponent"
	_hit.damage = def.profile.damage
	_hit.damage_type_id = def.profile.damage_type_id
	_hit.damage_tag = def.profile.damage_tag
	_hit.auto_report = true
	_hit.report_mode = HitComponent.ReportMode.ON_ENTER   # 1 hit por alvo por hitbox
	_hit.attacker = owner
	_hit.priority = def.priority
	add_child(_hit)

	_apply_shape()


func _physics_process(delta: float) -> void:
	if _expired:
		return
	if not is_instance_valid(owner_node):
		_expire()
		return

	_elapsed += delta
	if _elapsed >= def.safety_timeout:
		_expire()
		return

	if _placed:
		# O mundo já viu esta hitbox por pelo menos 1 tick: pode contar frames e expirar.
		if _frame_source != null:
			if not is_instance_valid(_frame_source) or _frame_source.animation != _last_anim:
				_expire()   # a hitbox não sobrevive à animação em que nasceu
				return
			_steps += _new_animation_frames()
		else:
			_steps += 1
		if def.duration_frames > 0 and _steps >= def.duration_frames:
			_expire()
			return
		_apply_shape()
	else:
		_apply_shape()   # acompanha o espelhamento do dono já no tick de nascimento
	_placed = true


## Frames de animação vistos desde a última checagem (loop volta para 0: conta 1).
func _new_animation_frames() -> int:
	var current: int = _frame_source.frame
	var delta_frames: int = 0
	if current > _last_frame:
		delta_frames = current - _last_frame
	elif current < _last_frame:
		delta_frames = 1
	_last_frame = current
	return delta_frames


func _facing_flip() -> int:
	if is_instance_valid(owner_node) and owner_node.has_method("get_facing_flip"):
		return -1 if int(owner_node.get_facing_flip()) < 0 else 1
	return 1


## Tamanho e posição do retângulo neste frame. O ponto de ancoragem fica parado enquanto o
## retângulo cresce; o espelhamento inverte o X do offset e da âncora.
func _apply_shape() -> void:
	var s: Vector2 = def.size + def.grow_per_frame * float(_steps)
	if def.max_size.x > 0.0:
		s.x = minf(s.x, def.max_size.x)
	if def.max_size.y > 0.0:
		s.y = minf(s.y, def.max_size.y)
	s = Vector2(maxf(s.x, 1.0), maxf(s.y, 1.0))

	var flip: int = _facing_flip()
	var anchor := Vector2(def.grow_anchor.x if flip > 0 else 1.0 - def.grow_anchor.x, def.grow_anchor.y)
	var anchor_pos := Vector2(def.offset.x * float(flip), def.offset.y)

	_shape.size = s
	_col.position = anchor_pos - anchor * s + s * 0.5


## Desliga na hora e some. Deferred: pode ser chamado de dentro de um sinal de física.
func _expire() -> void:
	if _expired:
		return
	_expired = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	queue_free()
