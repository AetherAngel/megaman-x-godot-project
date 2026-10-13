# ui/hud/hp_bar/HPBar.gd
class_name HPBar
extends Node2D

## Barra de HP visual. Monta e gerencia unit sprites dinamicamente.
##
## Esta cena NUNCA lê dados de HPSystem diretamente.
## Quem conecta os signals é o HUD.gd (coordenador).
## HPBar só exibe — recebe dados empurrados via setup() e _on_units_changed().
##
## HIERARQUIA DA CENA (HPBar.tscn):
##   HPBar (Node2D — este script)
##   ├── Icon     (AnimatedSprite2D)  ← spr_bar1_icon.tres
##   ├── BarArea  (Node2D)            ← container de segmentos, spr_bar1_area.tres por segmento
##   ├── Units    (Node2D)            ← container dos unit sprites
##   ├── Limit    (AnimatedSprite2D)  ← spr_bar1_limit.tres
##   └── HPStateHandler (Node)        ← behaviors/HPStateHandler.gd
##
## POSICIONAMENTO — ENCADEADO A PARTIR DO ICON:
##   Você só escolhe a posição e o offset do ICON. Tudo mais deriva dele:
##     icon       → config.icon_offset (único ponto configurado manualmente)
##     bar_area   → EXATAMENTE icon.position (mesmo ponto de ancoragem, sem offset extra)
##     units      → mesma posição do bar_area (containers são siblings)
##     limit      → bar_area.position + (max_units atual × tamanho da unidade)
##   O limite SEMPRE reflete max_units atual — se o jogador ganha um HeartTank
##   e max_units cresce, o limite se reposiciona automaticamente.
##
## BAR_AREA NÃO É MAIS UM SPRITE ÚNICO:
##   BarArea agora é um CONTAINER (Node2D) que recebe um segmento de área por
##   unidade — exatamente como Units. Cada segmento de área é o "encaixe" de
##   fundo (14px) onde a unit (6px, centralizada) se encaixa por cima.
##   A visibilidade dos segmentos de área acompanha max_units (a capacidade
##   atual), crescendo junto com o limite quando o jogador ganha um HeartTank —
##   nunca um valor fixo.


# ── Constantes de layout (valores originais MMX) ──────────────
## Pixels por slot de unidade na vertical.
const UNIT_HEIGHT_PX:  int = 2
## Pixels por slot de unidade na horizontal.
const UNIT_WIDTH_PX:   int = 2
## Deslocamento X da unit sprite dentro da BarArea (centraliza 6px em 14px).
const UNIT_OFFSET_X:   int = 4
## Deslocamento Y dentro do slot (deixa 1px preto no topo).
const UNIT_OFFSET_Y:   int = 1

## Teto absoluto de unidades — define quantas unit sprites são pré-alocadas.
## Deve coincidir com HPSystemData.unit_cap. NÃO é usado para o cálculo
## visual do limite — isso usa max_units (atual), não este teto.
const UNIT_CAP: int = 32

# ── Sprite resources ──────────────────────────────────────────
const FRAMES_AREA:  SpriteFrames = preload("res://resources/animations/spr_bar1_area.tres")
const FRAMES_UNIT:  SpriteFrames = preload("res://resources/animations/spr_bar1_hp_unit.tres")
const FRAMES_ICON:  SpriteFrames = preload("res://resources/animations/spr_bar1_icon.tres")
const FRAMES_LIMIT: SpriteFrames = preload("res://resources/animations/spr_bar1_limit.tres")

# ── Nós ───────────────────────────────────────────────────────
@onready var icon:          AnimatedSprite2D = $Icon
## BarArea agora é um CONTAINER — recebe um segmento de área por unidade,
## exatamente como units_container. Renomeie/recrie o nó no editor: era
## AnimatedSprite2D, precisa virar Node2D (veja README de setup).
@onready var bar_area:        Node2D         = $BarArea
@onready var units_container: Node2D         = $Units
@onready var limit:         AnimatedSprite2D = $Limit
@onready var state_handler: HPStateHandler   = $HPStateHandler

# ── Estado ────────────────────────────────────────────────────
var config: HPBarConfig
var current_units: int = 0
var max_units: int     = 0
var _unit_sprites: Array[AnimatedSprite2D] = []
## Segmentos de fundo da área — um por slot de unidade, espelhando _unit_sprites.
var _area_sprites: Array[AnimatedSprite2D] = []


# ─────────────────────────────────────────────────────────────
# SETUP — chamado por HUD.gd
# ─────────────────────────────────────────────────────────────

## Inicializa a barra com a configuração e os valores de HP.
func setup(hp_config: HPBarConfig, initial_current: int, initial_max: int) -> void:
	config        = hp_config
	max_units     = initial_max
	current_units = initial_current

	_configure_sprites()
	_spawn_area_segments()
	_spawn_units()
	_update_area_visibility()
	_update_units_visibility()
	_position_icon_and_limit()


## Muda o ícone sem recriar tudo — usado na troca de personagem.
## animation_key: character_id em minúsculo + "_icon" (ex: "x_icon", "zero_icon").
func set_icon(character_id: StringName) -> void:
	if not icon:
		return
	var anim: String = character_id.to_lower() + "_icon"
	if icon.sprite_frames and icon.sprite_frames.has_animation(anim):
		icon.play(anim)
	else:
		push_warning("[HPBar] Animação de ícone não encontrada: '%s'" % anim)


# ─────────────────────────────────────────────────────────────
# RESPOSTA A EVENTOS — chamados por HUD.gd via signal
# ─────────────────────────────────────────────────────────────

## Recebe atualização de HP do HPSystem.units_changed.
## Compara com estado atual e direciona ao behavior correto.
func _on_units_changed(new_current: int, new_max: int) -> void:
	var prev_current := current_units
	var prev_max     := max_units

	current_units = new_current
	max_units     = new_max

	# Max mudou (HeartTank) — reposiciona o limite e revela mais segmentos
	# de área para refletir o novo teto. Ambos sempre acompanham max_units
	# atual, nunca um valor fixo — crescem e começam juntos, como pedido.
	if new_max != prev_max:
		_position_icon_and_limit()
		_update_area_visibility()

	# Aumento de max (HeartTank).
	if new_max > prev_max:
		state_handler.start_increase(new_max - prev_max)
		return

	# Dano.
	if new_current < prev_current:
		state_handler.start_damage(prev_current - new_current)
		return

	# Cura.
	if new_current > prev_current:
		state_handler.start_heal(new_current - prev_current)
		return


# ─────────────────────────────────────────────────────────────
# API DE BEHAVIORS — chamada pelos behaviors via HPStateHandler
# ─────────────────────────────────────────────────────────────

## Esconde a unit mais alta visível (dano).
func hide_top_unit() -> void:
	for i in range(current_units, -1, -1):
		if i < _unit_sprites.size() and _unit_sprites[i].visible:
			_unit_sprites[i].visible = false
			return


## Mostra a próxima unit acima das visíveis (cura ou boss fill).
func show_next_unit() -> void:
	for i in _unit_sprites.size():
		if not _unit_sprites[i].visible:
			_unit_sprites[i].visible = true
			return


## Força a exibição de exatamente `count` unidades (usado pelo BossHPBehavior).
func force_show_units(count: int) -> void:
	for i in _unit_sprites.size():
		_unit_sprites[i].visible = (i < count)


# ─────────────────────────────────────────────────────────────
# SETUP INTERNO
# ─────────────────────────────────────────────────────────────

func _configure_sprites() -> void:
	# IMPORTANTE: centered = false força .position a significar "canto
	# superior esquerdo" em vez do padrão do Godot ("centro do sprite").
	# Sem isso, toda a matemática de empilhamento pixel-perfect quebra.

	# Icon
	icon.centered = false
	icon.sprite_frames = FRAMES_ICON
	if config:
		if not config.icon_override.is_empty():
			set_icon(config.icon_override)
		else:
			set_icon(CharacterManagement.get_active_id())
	
	# Limit
	limit.centered = false
	limit.sprite_frames = FRAMES_LIMIT
	limit.play("default")


## Pré-aloca UNIT_CAP segmentos de fundo da área — um por slot de unidade.
## Cada segmento é o "encaixe" de 14px onde a unit (6px) se centraliza.
## Visível até max_units (capacidade ATUAL), não current_units (HP atual) —
## a área mostra onde HP PODE existir, as units mostram onde HP EXISTE.
func _spawn_area_segments() -> void:
	for child in bar_area.get_children():
		child.queue_free()
	_area_sprites.clear()

	for i in UNIT_CAP:
		var spr := AnimatedSprite2D.new()
		spr.centered = false
		spr.sprite_frames = FRAMES_AREA
		spr.play("default")
		spr.visible = false
		_set_area_position(spr, i)
		bar_area.add_child(spr)
		_area_sprites.append(spr)


func _update_area_visibility() -> void:
	for i in _area_sprites.size():
		_area_sprites[i].visible = (i < max_units)


## Posição de cada segmento de área é LOCAL ao bar_area (container).
## Sem UNIT_OFFSET_X/Y — a área ocupa o slot INTEIRO (14px), diferente da
## unit que é centralizada e nudada 1px (deixando o trim preto no topo).
func _set_area_position(spr: AnimatedSprite2D, index: int) -> void:
	match config.orientation if config else HPBarConfig.Orientation.VERTICAL:
		HPBarConfig.Orientation.VERTICAL:
			spr.position = Vector2(0, -(index * UNIT_HEIGHT_PX))
		HPBarConfig.Orientation.HORIZONTAL:
			spr.position = Vector2(index * UNIT_WIDTH_PX, 0)


func _spawn_units() -> void:
	# Limpa units anteriores se existirem (ex: reinitialize após HeartTank).
	for child in units_container.get_children():
		child.queue_free()
	_unit_sprites.clear()

	# Pré-aloca UNIT_CAP sprites — exibe apenas até max_units.
	for i in UNIT_CAP:
		var spr := AnimatedSprite2D.new()
		spr.centered = false  # mesma ancoragem por canto usada em icon/bar_area/limit
		spr.sprite_frames = FRAMES_UNIT
		spr.play("default")
		spr.visible = false
		_set_unit_position(spr, i)
		units_container.add_child(spr)
		_unit_sprites.append(spr)


func _update_units_visibility() -> void:
	for i in _unit_sprites.size():
		_unit_sprites[i].visible = (i < current_units)


## Posição de cada unit é LOCAL ao units_container.
## units_container, por sua vez, é posicionado em _position_icon_and_limit()
## para coincidir com bar_area — então essas posições locais continuam
## corretas independente de onde o icon estiver na tela.
func _set_unit_position(spr: AnimatedSprite2D, index: int) -> void:
	match config.orientation if config else HPBarConfig.Orientation.VERTICAL:
		HPBarConfig.Orientation.VERTICAL:
			# index 0 = bottom, index max-1 = top.
			# bar_area cresce para cima (y negativo no Godot 2D).
			spr.position = Vector2(
				UNIT_OFFSET_X,
				-(index * UNIT_HEIGHT_PX + UNIT_OFFSET_Y)
			)
		HPBarConfig.Orientation.HORIZONTAL:
			spr.position = Vector2(
				index * UNIT_WIDTH_PX,
				UNIT_OFFSET_Y
			)


## Encadeia a posição de bar_area, units e limit a partir do ICON.
## Você só escolhe a posição/offset do ícone — o resto é derivado matematicamente.
##
## Chamado em setup() e sempre que max_units mudar (HeartTank),
## pois o limite precisa refletir o teto ATUAL, não um valor fixo.
func _position_icon_and_limit() -> void:
	if not config:
		return

	# Comprimento da barra até o max_units ATUAL — não o UNIT_CAP fixo.
	# Cresce automaticamente quando o jogador coleta um HeartTank.
	var unit_size := UNIT_HEIGHT_PX if config.orientation == HPBarConfig.Orientation.VERTICAL else UNIT_WIDTH_PX
	var bar_length := max_units * unit_size

	match config.orientation:
		HPBarConfig.Orientation.VERTICAL:
			# 1. Icon — único ponto configurado manualmente.
			icon.position = config.icon_offset

			# 2. BarArea — EXATAMENTE no mesmo ponto do icon (sem offset extra).
			#    Testado e confirmado: subtrair a altura do icon aqui introduzia
			#    um gap indesejado. O ponto de ancoragem do icon já é o início
			#    correto da barra.
			bar_area.position = icon.position

			# 3. Units — mesmo ponto de origem do BarArea.
			#    São siblings na hierarquia, então precisam ser sincronizados manualmente.
			units_container.position = bar_area.position - Vector2(0, -1)

			# 4. Limit — no fim da barra, considerando max_units ATUAL.
			limit.position = bar_area.position + Vector2(0, -bar_length) + config.limit_offset

		HPBarConfig.Orientation.HORIZONTAL:
			icon.position = config.icon_offset
			bar_area.position = icon.position
			units_container.position = bar_area.position
			limit.position = bar_area.position + Vector2(bar_length, 0) + config.limit_offset
