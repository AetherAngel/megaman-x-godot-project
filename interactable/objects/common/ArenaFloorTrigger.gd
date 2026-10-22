# levels/common/ArenaFloorTrigger.gd
extends Area2D

## Marca o CHÃO REAL da arena — onde o player de fato termina de entrar.
## Responsabilidades:
##   1. Notifica a câmera (pan ou lock, dependendo do mode configurado na porta)
##   2. Entrega o boss ao BossFlowManager para orquestrar TODO o fluxo
##
## NÃO chama GameManager.start_boss_intro() diretamente — isso era
## responsabilidade do GameManager, que foi movida pro BossFlowManager.
##
## ESTRUTURA NO EDITOR:
##   ArenaFloorTrigger (Area2D, raiz, este script)
##   └── CollisionShape2D  (cobrindo o chão real da arena)
##   Sem sprite — não precisa ser visível.
##
## IMPORTANTE: Collision Mask deve incluir a layer física do Player.

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Rearma o gatilho para uma nova tentativa da luta (grupo "arena_resettable").
func reset_arena() -> void:
	_triggered = false


func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	if GameManager.current_state != GameManager.GameState.ENTERING_ARENA:
		return

	_triggered = true

	# Notifica a câmera — pan ou lock dependendo do mode.
	var cam := get_tree().get_first_node_in_group("GmCamera") as StablePixelCamera
	if cam:
		cam.on_player_reached_floor()

	# Entrega ao BossFlowManager — ele cuida de TODO o resto:
	# intro_cutscene → BOSS_PRESENTATION → BOSS_FIGHT → death → weapon.
	if GameManager.current_boss:
		BossFlowManager.begin(GameManager.current_boss)
