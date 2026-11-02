# systems/hazard/PillarHazard.gd
class_name PillarHazard
extends Area2D

## Hazard em forma de coluna que cresce a partir de uma base fixa, segura e recolhe.
## Serve para cenário (colocado no mapa), ataque de boss (SPAWN_OBJECT) ou reação
## (instanciado por outro sistema). O que muda entre lava, gelo, espinhos etc. é só o
## Resource `config` (PillarHazardDef) — este script não conhece nenhum tema.
##
## ESTRUTURA
##   Raiz Area2D ........... origem = BASE do pilar. Escala do nó = 1 (use config.pillar_scale).
##   CollisionShape2D ...... a hitbox (retângulo criado por instância, nunca compartilhado).
##   HitComponent .......... dano; filho DIRETO da raiz, com este nome (o boss o procura assim).
##   Visual (criado aqui) .. Node2D escalado por pillar_scale; contém as duas máscaras:
##       BodyMask ........... recorta os Body na base (revelação progressiva)
##       TopMask ............ recorta o Top na base (esconde o que estaria abaixo dela)
##
## COMO O CORPO APARECE: os Body ficam PENDURADOS no Top — o primeiro Body começa no pixel
## imediatamente abaixo do Top, sempre. A máscara os corta na base. Conforme o Top sobe, mais
## Body "sai do chão", de forma contínua. (Se os Body ficassem fixos a partir da base, a
## textura só emendaria com o Top em alturas múltiplas de 24 e apareceria uma costura.)
##
## REGRA CENTRAL: `_altura` é a ÚNICA fonte da verdade do crescimento. Em todo tick,
## _apply_height() lê esse valor e atualiza máscara, Top e hitbox JUNTOS. Não existe
## cálculo paralelo, então a hitbox nunca passa do que a máscara já revelou.
##
## UNIDADES: `_altura` está em px ORIGINAIS (tamanho da arte). pillar_scale é aplicado
## uma única vez, em _apply_height(), na conversão para o mundo.

## Emitido ao fim de cada descida (fim de cada ciclo).
signal cycle_finished

enum CycleState {
	IDLE,     ## ainda não começou (invisível, sem hitbox)
	WAITING,  ## start_delay: só o Top espiando, sem hitbox
	RISING,   ## _altura aumenta, hitbox cresce junto
	HOLDING,  ## altura máxima efetiva, hitbox no máximo
	FALLING,  ## _altura diminui, hitbox encolhe junto
	RESTING,  ## rest_time (só em loop): Top espiando, SEM hitbox
	DONE,     ## one-shot concluído (o nó se libera)
}

## Abaixo disso (px de mundo) a hitbox fica desligada: um retângulo de ~0px é inútil
## e instável para a física.
const _MIN_HITBOX_HEIGHT := 1.0

## O Resource deste pilar. Arraste aqui o .tres (como se faz com CharacterData).
@export var config: PillarHazardDef

@export_group("Execution")
## Começa sozinho no _ready(). Se false, chame start().
@export var auto_start: bool = true
## true = repete (sobe, segura, desce, descansa). false = um ciclo e se libera.
@export var loop: bool = false
## Descanso entre ciclos do loop. Sem hitbox, só o Top espiando.
@export var rest_time: float = 1.0
## Atraso (s) antes do PRIMEIRO crescimento. Só o Top espia o chão; sem hitbox.
@export var start_delay: float = 0.0

var _state: CycleState = CycleState.IDLE
var _altura: float = 0.0          # px originais — fonte única da verdade
var _max_altura: float = 0.0      # altura efetiva máxima (px originais)
var _timer: float = 0.0
var _dir: float = -1.0            # -1 = cresce para cima, +1 = para baixo
var _scale: Vector2 = Vector2.ONE
var _top_size: Vector2 = Vector2.ZERO
var _body_size: Vector2 = Vector2.ZERO
var _rise_speed: float = 1.0
var _fall_speed: float = 1.0
var _hitbox_enabled: bool = false

var _visual: Node2D = null
var _body_mask: Control = null
var _body_content: Node2D = null   # pilha de Body; origem = junção Top/Body
var _top_mask: Control = null
var _top: AnimatedSprite2D = null
var _bodies: Array[AnimatedSprite2D] = []
var _shape: CollisionShape2D = null
var _rect: RectangleShape2D = null
var _hit: HitComponent = null


func _ready() -> void:
	set_physics_process(false)

	if config == null or not config.is_buildable():
		push_error("PillarHazard '%s': config ausente, ou sem sprite do Top (e do Body, se há segmentos)." % name)
		return
	if scale != Vector2.ONE:
		push_warning("PillarHazard '%s': escala do nó é ignorada pela colisão. Use config.pillar_scale." % name)

	_cache_config()
	_setup_physics()
	_build_visual()
	_apply_height()

	if auto_start:
		start()


# ── API pública ──────────────────────────────────────────────

## Inicia o ciclo. Ignorado se já estiver rodando.
func start() -> void:
	if _state != CycleState.IDLE or _visual == null:
		return
	_altura = 0.0
	if start_delay > 0.0:
		_enter(CycleState.WAITING, start_delay)
	else:
		_enter(CycleState.RISING)


## Interrompe e esconde tudo (sem hitbox). start() pode ser chamado de novo.
## O desligamento da hitbox é adiado ao fim do frame: assim stop() pode ser chamado com
## segurança de dentro de um callback de colisão (ex: body_entered).
func stop() -> void:
	if _visual == null:
		return
	_altura = 0.0
	_state = CycleState.IDLE
	set_physics_process(false)
	_apply_height.call_deferred()


# ── Ciclo ────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	match _state:
		CycleState.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_enter(CycleState.RISING)
		CycleState.RISING:
			_altura = minf(_altura + _rise_speed * delta, _max_altura)
			if _altura >= _max_altura:
				if config.hold_time > 0.0:
					_enter(CycleState.HOLDING, config.hold_time)
				else:
					_enter(CycleState.FALLING)
		CycleState.HOLDING:
			_timer -= delta
			if _timer <= 0.0:
				_enter(CycleState.FALLING)
		CycleState.FALLING:
			_altura = maxf(_altura - _fall_speed * delta, 0.0)
			if _altura <= 0.0:
				_finish_cycle()
		CycleState.RESTING:
			_timer -= delta
			if _timer <= 0.0:
				_enter(CycleState.RISING)

	# Único ponto onde visual e colisão são atualizados: sempre juntos, sempre do mesmo _altura.
	_apply_height()


func _enter(new_state: CycleState, duration: float = 0.0) -> void:
	_state = new_state
	_timer = duration
	set_physics_process(true)


func _finish_cycle() -> void:
	_altura = 0.0
	if loop:
		if rest_time > 0.0:
			_enter(CycleState.RESTING, rest_time)
		else:
			_enter(CycleState.RISING)
		_apply_height()
		cycle_finished.emit()
		return

	# One-shot: desliga tudo ANTES de liberar, para nunca sobrar hitbox ativa.
	_state = CycleState.DONE
	set_physics_process(false)
	_apply_height()
	cycle_finished.emit()
	queue_free()


# ── Sincronia visual + colisão ───────────────────────────────

## Arredonda uma altura (px originais) para um número inteiro de pixels de MUNDO.
## Mantém o Top e a borda das máscaras alinhados ao pixel, sem costura entre eles.
func _snap(altura: float) -> float:
	return roundf(altura * _scale.y) / _scale.y


func _apply_height() -> void:
	if _visual == null:
		return

	var altura := _snap(_altura)
	# O Top espia o chão (peek) enquanto o pilar está "vivo", mas isso é SÓ visual:
	# a hitbox usa `altura`, nunca `shown`. shown >= altura sempre.
	var shown := _snap(maxf(_altura, minf(config.peek_height, _max_altura)))

	_update_visual(shown)
	_update_hitbox(altura)


## `shown`: distância (px originais) da base até a ponta do Top.
func _update_visual(shown: float) -> void:
	_visual.visible = _state != CycleState.IDLE and _state != CycleState.DONE
	var down := _dir > 0.0

	# Top: a máscara cobre [base .. ponta]; o que ficaria abaixo da base é cortado.
	var top_half := _top_size.x * 0.5
	_top_mask.visible = shown > 0.0
	_top_mask.position = Vector2(-top_half, 0.0 if down else -shown)
	_top_mask.size = Vector2(_top_size.x, shown)
	var top_y := (shown - _top_size.y) if down else -shown
	_top.position = Vector2(-top_half, top_y) - _top_mask.position

	# Body: pendurado no Top; a janela (máscara) vai da base até o pixel logo abaixo do Top.
	var body_visible := clampf(shown - _top_size.y, 0.0, _bodies.size() * _body_size.y)
	_body_mask.visible = body_visible > 0.0
	_body_mask.position = Vector2(-_body_size.x * 0.5, 0.0 if down else -body_visible)
	_body_mask.size = Vector2(_body_size.x, body_visible)
	# A pilha de Body acompanha o Top: sua origem é a junção Top/Body (no espaço do Visual).
	var junction_y := _dir * (shown - _top_size.y)
	_body_content.position = Vector2(0.0, junction_y) - _body_mask.position


func _update_hitbox(altura: float) -> void:
	var h_world := altura * _scale.y
	var allowed := _state == CycleState.RISING or _state == CycleState.HOLDING or _state == CycleState.FALLING
	var active := allowed and h_world >= _MIN_HITBOX_HEIGHT

	if active:
		_rect.size = Vector2(config.hitbox_width * _scale.x, h_world)
		_shape.position = Vector2(0.0, _dir * h_world * 0.5)

	if active != _hitbox_enabled:
		_hitbox_enabled = active
		_shape.disabled = not active
		# `monitoring` é o que corta o dano NA HORA: desligá-lo limpa as sobreposições e emite
		# body_exited agora. Só desabilitar a shape não bastava — a física só a enxerga no tick
		# seguinte, e o HitComponent ainda reportaria um hit no primeiro tick do rest_time.
		monitoring = active


# ── Montagem (uma vez, no _ready) ────────────────────────────

func _cache_config() -> void:
	_scale = config.get_safe_scale()
	_dir = 1.0 if config.growth_direction == PillarHazardDef.GrowthDirection.DOWN else -1.0
	_top_size = config.get_top_size()
	_body_size = config.get_body_size()
	_max_altura = config.get_effective_height()
	if config.rise_speed <= 0.0 or config.fall_speed <= 0.0:
		push_warning("PillarHazard '%s': rise_speed/fall_speed devem ser > 0." % name)
	_rise_speed = maxf(config.rise_speed, 0.001)
	_fall_speed = maxf(config.fall_speed, 0.001)


func _setup_physics() -> void:
	z_index = config.z_index
	collision_layer = 0
	collision_mask = config.hitbox_mask
	monitorable = false

	_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "CollisionShape2D"
		add_child(_shape)
	_rect = RectangleShape2D.new()   # um por instância: nunca compartilhar entre pilares
	_shape.shape = _rect
	_shape.disabled = true
	monitoring = false
	_hitbox_enabled = false

	_hit = get_node_or_null("HitComponent") as HitComponent
	if _hit:
		_hit.damage = config.damage
		_hit.damage_type_id = config.damage_type_id
		_hit.damage_tag = config.damage_tag
	else:
		push_warning("PillarHazard '%s': sem filho 'HitComponent' — o pilar não causará dano." % name)


func _build_visual() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	_visual.scale = _scale          # ÚNICO lugar onde pillar_scale vira escala de nó
	add_child(_visual)

	# Ordem de desenho: Body primeiro, Top por cima.
	_body_mask = _make_mask("BodyMask")
	_visual.add_child(_body_mask)
	_body_content = Node2D.new()
	_body_content.name = "BodyContent"
	_body_mask.add_child(_body_content)

	var down := _dir > 0.0
	for i in config.max_body_segments:
		var seg := _make_sprite(config.body_frames, config.body_animation)
		seg.name = "Body%d" % i
		# Slot i fica a i*altura da junção com o Top, afastando-se dele — emendados, sem vão.
		var y := (-(i + 1) * _body_size.y) if down else (i * _body_size.y)
		seg.position = Vector2(-_body_size.x * 0.5, y)
		_body_content.add_child(seg)
		_bodies.append(seg)

	_top_mask = _make_mask("TopMask")
	_visual.add_child(_top_mask)
	_top = _make_sprite(config.top_frames, config.top_animation)
	_top.name = "Top"
	_top_mask.add_child(_top)

	# Todas as animações começam no mesmo tick → ficam em fase para sempre.
	_top.play(_top.animation)
	for seg in _bodies:
		seg.play(seg.animation)


func _make_mask(node_name: String) -> Control:
	var mask := Control.new()
	mask.name = node_name
	mask.clip_contents = true
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.focus_mode = Control.FOCUS_NONE
	return mask


func _make_sprite(frames: SpriteFrames, anim: StringName) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = PillarHazardDef.resolve_animation(frames, anim)
	sprite.centered = false         # posição = canto superior esquerdo: geometria exata, sem meio-pixel
	sprite.flip_v = config.flip_art_when_down and _dir > 0.0
	return sprite
