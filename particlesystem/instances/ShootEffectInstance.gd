class_name ShootEffectInstance
extends Node2D


func setup(def: ShootEffectDef, facing_right: bool) -> void:
	z_index = def.z_index
	scale   = def.base_scale

	# Espelha horizontalmente se virado para esquerda
	if not facing_right:
		scale.x *= -1.0

	var sprite := AnimatedSprite2D.new()
	add_child(sprite)

	if def.sprite_frames:
		sprite.sprite_frames = def.sprite_frames

		if sprite.sprite_frames.has_animation(def.animation):
			sprite.animation_finished.connect(queue_free)
			sprite.play(def.animation)
			return

	# Fallback: sem animação válida, usa o lifetime como timer
	get_tree().create_timer(def.lifetime).timeout.connect(queue_free)
