# ScreenFade.gd
# Autoload — adicione em Project > Autoloads com o nome "ScreenFade"
extends CanvasLayer

## Fade de tela inteira (preto), reutilizável: morte, troca de fase, cutscenes.
## Só EXECUTA o fade — quem chama decide o momento. Não conhece Player nem cutscene.
##
## Uso:
##   ScreenFade.fade_out(0.5)   # escurece
##   ScreenFade.fade_in(0.5)    # clareia
##   await ScreenFade.fade_finished

## Emitido quando o fade em andamento termina.
signal fade_finished

## Acima do HUD e dos demais CanvasLayers do jogo.
const FADE_LAYER := 100

var _rect: ColorRect = null
var _tween: Tween = null


func _ready() -> void:
	layer = FADE_LAYER
	# Continua funcionando com o jogo pausado (o CutsceneSequencer também é ALWAYS).
	process_mode = Node.PROCESS_MODE_ALWAYS

	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


# ── API ──────────────────────────────────────────────────────

## Escurece a tela. duration <= 0 aplica na hora.
func fade_out(duration: float = 0.5) -> void:
	_fade_to(1.0, duration)


## Clareia a tela. duration <= 0 aplica na hora.
func fade_in(duration: float = 0.5) -> void:
	_fade_to(0.0, duration)


# ── Interno ──────────────────────────────────────────────────

func _fade_to(target_alpha: float, duration: float) -> void:
	# Um fade novo substitui o que estiver rodando.
	if _tween and _tween.is_valid():
		_tween.kill()

	if duration <= 0.0:
		_rect.modulate.a = target_alpha
		fade_finished.emit()
		return

	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", target_alpha, duration)
	_tween.finished.connect(fade_finished.emit)
