# levels/test_stage/ReadySystem.gd
extends CanvasLayer
@onready var ready_sprite: AnimatedSprite2D = $ReadySprite
signal ready_finished

func _ready() -> void:
	visible = false

func play_ready() -> void:
	visible = true
	ready_sprite.visible = true
	
	var ready_path = "res://resources/animations/spr_player_ready.tres"
	if ResourceLoader.exists(ready_path):
		ready_sprite.sprite_frames = load(ready_path)
		ready_sprite.play("ready")
		
		ready_sprite.scale = Vector2(2.5, 2.5)
		ready_sprite.modulate = Color(1, 1, 1, 0)
		
		var tween = create_tween()
		tween.tween_property(ready_sprite, "scale", Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(ready_sprite, "modulate", Color.WHITE, 0.25)
		
		await tween.finished
		await get_tree().create_timer(1.5).timeout
		
		tween = create_tween()
		tween.tween_property(ready_sprite, "modulate", Color(1, 1, 1, 0), 0.3)
		await tween.finished
		
		ready_sprite.visible = false  # ← só esconde o sprite, não o CanvasLayer inteiro
		ready_finished.emit()
	else:
		print("⚠️ spr_player_ready.tres não encontrado!")
		ready_finished.emit()
