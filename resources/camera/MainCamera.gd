# MainCamera.gd
extends Camera2D
class_name StablePixelCamera

## Câmera principal do jogo.
##
## Durante o gameplay normal: segue o player pixel a pixel.
##
## Durante boss intro:
##   is_centered = false → pan horizontal (esq/dir) ao player entrar na porta
##   is_centered = true  → trava no centro da arena quando player toca o chão
##                          (sem pan — útil para portas no chão/teto)
##
## Ao entrar em BOSS_FIGHT: retorna suavemente ao player e
## retoma o seguimento normal.
##
## TODO — safeguard "entrar por cima":
##   Quando player cair direto na arena (sem porta), a câmera não deve
##   se mover. Adicionar um @export var ignore_pan: bool = false na porta
##   pra cobrir esse caso quando for implementado.

enum BossIntroMode { NONE, PAN, CENTERED }

## Distância do pan em pixels. Ajuste no Inspector até ficar certo
## visualmente para a arena do Magma Dragoon.
@export var pan_distance: float = 160.0
## Duração do pan de ida (em segundos).
@export var pan_duration: float = 0.6
## Duração do retorno ao player quando BOSS_FIGHT começa.
@export var return_duration: float = 0.5

var target: Node2D
var _is_following: bool = true
var _boss_intro_mode: BossIntroMode = BossIntroMode.NONE
var _pan_direction: Vector2 = Vector2.ZERO
var _active_tween: Tween

## True quando o pan do boss intro terminou.
## BossFlowManager consulta isso em begin() para não perder o signal
## caso o pan já tenha terminado antes da conexão ser feita.
var pan_done: bool = false

signal pan_finished


func _ready() -> void:
	process_priority = 999
	add_to_group("GmCamera")
	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("player")
	GameManager.state_changed.connect(_on_state_changed)


func _physics_process(_delta: float) -> void:
	if not _is_following or not target:
		return
	global_position = target.global_position.round()


# ─────────────────────────────────────────────────────────────
# API — chamada pela porta e pelo ArenaFloorTrigger
# ─────────────────────────────────────────────────────────────

## Chamada pela porta (MMX_Door) quando o player entra.
## SÓ registra o behavior e a direção — NÃO inicia o pan aqui.
## O pan (ou lock) só acontece quando ArenaFloorTrigger chamar
## on_player_reached_floor().
func prepare_boss_intro(direction: Vector2, is_centered: bool) -> void:
	_pan_direction = direction
	if is_centered:
		_boss_intro_mode = BossIntroMode.CENTERED
	else:
		_boss_intro_mode = BossIntroMode.PAN


## Chamada pelo ArenaFloorTrigger quando o player toca o chão da arena.
## É aqui que a câmera de fato age — pan ou lock, dependendo do mode.
func on_player_reached_floor() -> void:
	match _boss_intro_mode:
		BossIntroMode.PAN:
			_start_pan()
		BossIntroMode.CENTERED:
			_is_following = false


# ─────────────────────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────────────────────

func _start_pan() -> void:
	_is_following = false
	pan_done = false
	_kill_tween()
	_active_tween = create_tween()
	_active_tween.tween_property(
		self, "global_position",
		global_position + _pan_direction * pan_distance,
		pan_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _active_tween.finished
	pan_done = true
	pan_finished.emit()


func _return_to_player() -> void:
	if not target:
		_is_following = true
		return
	_kill_tween()
	_active_tween = create_tween()
	_active_tween.tween_property(
		self, "global_position",
		target.global_position.round(),
		return_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _active_tween.finished
	_boss_intro_mode = BossIntroMode.NONE
	_is_following = true


func _kill_tween() -> void:
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()


func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.BOSS_FIGHT:
		_return_to_player()
