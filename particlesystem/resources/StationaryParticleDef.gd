class_name StationaryParticleDef
extends Resource

@export_group("Visuals")
@export var sprite_frames: SpriteFrames
## Animação por nível. Índice 0 = lv0, índice 1 = lv1, etc.
## String vazia = esconde o efeito naquele nível.
@export var level_animations: Array[String] = ["charge_lv0", "charge_lv1", "charge_lv2"]


@export_group("Transform")
## Offset em relação ao marker ou nó pai.
@export var offset: Vector2 = Vector2.ZERO
@export var base_scale: Vector2 = Vector2.ONE
@export var z_index: int = 10
## Se true, espelha horizontalmente quando o dono vira para a esquerda.
@export var flip_with_facing: bool = true

@export_group("SFX")
## SFX tocado quando set_level() muda para um nível específico.
## ATENÇÃO: esse sfx é one-shot (play_sfx). Se o caller já gerencia
## o áudio desse efeito via play_loop/play_then_loop, deixe vazio
## para evitar conflito.
@export var level_sfx: Array[String] = []
## Ponto de início do loop em segundos para o SFX de charge (MMX-style).
## 0.0 = loop do começo. Qualquer valor > 0 = intro toca uma vez,
## depois só o tail (loop_begin_sec → fim) repete.
## Este valor sobrescreve o "loop_begin_sec" do sounds.json se > 0.
@export var loop_begin_sec: float = 0.0
