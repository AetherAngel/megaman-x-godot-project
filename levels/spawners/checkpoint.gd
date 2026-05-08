# Checkpoint.gd
# Attach na raiz da cena Checkpoint.tscn (Node2D).
#
# Modos de operação (definidos no Inspector):
#   is_checkpoint = false, is_teleport = false → PlayerSpawn (padrão)
#   is_checkpoint = true                       → Checkpoint
#   is_teleport   = true  (e is_checkpoint false) → Teleport
class_name Checkpoint
extends Node2D

# ── Flags de comportamento ────────────────────────────────────
@export_group("Comportamento")
## Se true, age como checkpoint de respawn.
## Tem prioridade sobre is_teleport.
@export var is_checkpoint: bool = false

## Se true (e is_checkpoint = false), age como teleporte.
@export var is_teleport: bool = false

# ── Teleport ─────────────────────────────────────────────────
@export_group("Teleport")
## Caminho para o Node2D/Marker2D de destino na mesma cena.
## Ignorado se target_scene estiver preenchido.
@export var target_position_path: NodePath = NodePath("")

## Cena de destino. Se preenchido, troca de cena ao teleportar.
@export_file("*.tscn") var target_scene: String = ""

# ── Player ───────────────────────────────────────────────────
@export_group("Player")
## Cena do player. Usada apenas no modo PlayerSpawn.
@export_file("*.tscn") var player_scene: String = "res://player/player.tscn"

# ── Nós internos ─────────────────────────────────────────────
@onready var _sprite:       AnimatedSprite2D = $AnimatedSprite2D
@onready var _detection:    Area2D           = $DetectionArea
@onready var _walkable:     StaticBody2D     = $WalkableArea
@onready var _center:       Marker2D         = $CenterPoint
@onready var _spawner:      Marker2D         = $PlayerSpawner

# ── Estado ───────────────────────────────────────────────────
var _mode: String = "spawn"   # "spawn" | "checkpoint" | "teleport"


func _ready() -> void:
	_resolve_mode()
	_configure_nodes()

	if _mode == "spawn":
		_spawn_player()
	elif _mode == "checkpoint":
		_detection.body_entered.connect(_on_player_entered_checkpoint)
	elif _mode == "teleport":
		_detection.body_entered.connect(_on_player_entered_teleport)


# ── Resolução do modo ─────────────────────────────────────────

func _resolve_mode() -> void:
	if is_checkpoint:
		_mode = "checkpoint"
	elif is_teleport:
		_mode = "teleport"
	else:
		_mode = "spawn"


# ── Configuração dos nós por modo ────────────────────────────

func _configure_nodes() -> void:
	match _mode:
		"spawn":
			# Desativa tudo exceto o PlayerSpawner.
			_sprite.visible    = false
			_sprite.process_mode = Node.PROCESS_MODE_DISABLED
			_detection.monitoring  = false
			_detection.monitorable = false
			_walkable.process_mode = Node.PROCESS_MODE_DISABLED
			_center.visible    = false

		"checkpoint", "teleport":
			# PlayerSpawner não é usado — desativa para não interferir.
			_spawner.visible = false


# ── Modo PlayerSpawn ──────────────────────────────────────────

func _spawn_player() -> void:
	if not ResourceLoader.exists(player_scene):
		push_error("Checkpoint (spawn): player_scene não encontrado: " + player_scene)
		return

	var player = load(player_scene).instantiate()
	player.z_index = 10
	player.global_position = _spawner.global_position
	get_tree().current_scene.add_child.call_deferred(player)


# ── Modo Checkpoint ───────────────────────────────────────────

func _on_player_entered_checkpoint(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	# Se este checkpoint já é o ativo, descarta — não faz nada.
	if GameManager.active_checkpoint == self:
		return

	# Atualiza o checkpoint ativo no GameManager.
	GameManager.active_checkpoint = self
	_sprite.play("active")
	print("✅ Checkpoint ativado: ", name)

# Função apenas com intenção de debug
func debug_trigger(player: Node) -> void:
	print("🔍 [Checkpoint DEBUG] nome=%s  modo=%s  ativo=%s" % [
		name,
		_mode,
		str(GameManager.active_checkpoint == self)
	])
	match _mode:
		"checkpoint":
			_on_player_entered_checkpoint(get_tree().get_first_node_in_group("player"))
		"teleport":
			_on_player_entered_teleport(get_tree().get_first_node_in_group("player"))
		"spawn":
			print("⚠️  Modo spawn — nenhum comportamento de trigger.")
	player.global_position = _center.global_position
	player.process_mode    = Node.PROCESS_MODE_INHERIT
	player.visible         = true

	# Reinicia o estado do player via state machine se disponível.
	if player.has_node("StateMachine"):
		player.get_node("StateMachine").change_state("Intro")

# Chamado pelo sistema de respawn quando o player precisa renascer.
func respawn_player(player: Node) -> void:
	player.global_position = _center.global_position
	player.process_mode    = Node.PROCESS_MODE_INHERIT
	player.visible         = true

	# Reinicia o estado do player via state machine se disponível.
	if player.has_node("StateMachine"):
		player.get_node("StateMachine").change_state("Intro")


# ── Modo Teleport ─────────────────────────────────────────────

func _on_player_entered_teleport(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	# Teleporte inter-cena.
	if not target_scene.is_empty():
		if ResourceLoader.exists(target_scene):
			get_tree().change_scene_to_file(target_scene)
		else:
			push_error("Checkpoint (teleport): target_scene não encontrado: " + target_scene)
		return

	# Teleporte intra-cena — move o player para target_position_path.
	if not target_position_path.is_empty():
		var dest := get_node_or_null(target_position_path)
		if dest is Node2D:
			body.global_position = (dest as Node2D).global_position
			return
		push_error("Checkpoint (teleport): target_position_path inválido: " + str(target_position_path))
		return

	# Fallback: teleporta para o próprio CenterPoint.
	body.global_position = _center.global_position
