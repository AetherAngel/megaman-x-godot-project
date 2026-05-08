class_name Character
extends Actor

# ── Pixel Snap ───────────────────────────────────────────────
# pixel_size = 1  →  escala 1:1 (sprite scale 1.0, 1.0)
# pixel_size = 2  →  escala 2:1 (sprite scale 0.5, 0.5)
# Regra: pixel_size = round(1.0 / sprite.scale.x)
@export var pixel_snap: bool = true
@export var pixel_size: int = 1

# referência à velocity pós move_and_slide (útil para states)
var current_velocity: Vector2 = Vector2.ZERO


# ============================================================
# NÃO há _physics_process aqui.
# Actor._physics_process roda para todos:
#   gravity → _process_state (Player hook) → _process_movement → snap
# ============================================================


# ── Sobrescreve _process_movement para adicionar pixel snap ──
func _process_movement(delta: float) -> void:
	super._process_movement(delta)          # Actor: bonus, conveyor, move_and_slide
	current_velocity = velocity             # captura resultado real da física
	_apply_pixel_snap()


# ── Pixel Snap ───────────────────────────────────────────────
func _apply_pixel_snap() -> void:
	if not pixel_snap:
		return
	# Trava a posição no grid de pixel correto para a escala usada
	global_position = global_position.snapped(Vector2(pixel_size, pixel_size))


# ── Reset ────────────────────────────────────────────────────
func stop_all_movement() -> void:
	velocity = Vector2.ZERO
	bonus_velocity = Vector2.ZERO
	conveyor_belt_speed = 0.0
	current_velocity = Vector2.ZERO
