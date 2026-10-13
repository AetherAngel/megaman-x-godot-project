# levels/common/MMX_Door.gd
extends Area2D
 
## Porta de entrada da arena do boss — FIX TEMPORÁRIO.
##
## Trava o player numa travessia forçada (animação congelada, posição
## transladada num vetor fixo) até ele sair da zona da porta — depois
## disso, gravidade natural assume o resto da queda (se houver) até o
## ArenaFloorTrigger, que de fato inicia a cutscene do boss.
##
## forced_direction é configurável por instância — se a porta estiver
## no chão (entrada vertical) em vez de lateral, é só mudar o vetor
## no Inspector, sem tocar em código.
##
## TODO antes de finalizar de verdade:
##   - Animação de abertura da porta (hoje só dispara, sem feedback visual)
##
## ESTRUTURA NO EDITOR:
##   MMX_Door (Area2D, raiz, este script)
##   ├── AnimatedSprite2D  (visual que você já tem)
##   └── CollisionShape2D  (zona de overlap — sem física de bloqueio)
##
## IMPORTANTE: o Collision Mask precisa incluir a layer física do Player.
 
## Direção da travessia forçada. Vector2.RIGHT = porta lateral típica.
## Vector2.DOWN = porta no chão (entrada vertical).
@export var forced_direction: Vector2 = Vector2.RIGHT
## Velocidade da travessia forçada, em pixels/segundo.
@export var forced_speed: float = 60.0
 
var _triggered: bool = false
 
 
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
 
 
func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
 
	_triggered = true
	GameManager.change_state(GameManager.GameState.ENTERING_ARENA)
 
	if body.has_method("enter_forced_movement"):
		body.enter_forced_movement(forced_direction, forced_speed)
 
 
func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("exit_forced_movement"):
		body.exit_forced_movement()
