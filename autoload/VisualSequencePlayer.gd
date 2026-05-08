# VisualSequencePlayer.gd
extends Node
class_name VisualSequenceController

signal sequence_finished(sequence_name: String)

@export var sequence_library: Array[VisualSequenceData]

var _sequence_map: Dictionary = {}

func _build_sequence_map() -> void:
	print("Instância:", get_path())
	print("Quantidade no sequence_library:", sequence_library.size())

	if not _sequence_map.is_empty():
		return

	for sequence in sequence_library:
		if sequence:
			print("Registrando sequência:", sequence.sequence_name)
			_sequence_map[sequence.sequence_name.to_lower()] = sequence

	print("Visual sequences carregadas:", _sequence_map.keys())


func _ready() -> void:
	_build_sequence_map()
	print("VisualSequencePlayer pronto:", get_path())
	print(name, " carregou sequências: ", _sequence_map.keys())

func play(player: Player, sequence_name: String) -> void:
	print("Play chamado em:", get_path())
	_build_sequence_map()

	print("Tentando tocar sequência:", sequence_name)
	print("Sequências disponíveis:", _sequence_map.keys())

	var sequence: VisualSequenceData = _sequence_map.get(sequence_name.to_lower())

	if not sequence:
		push_warning("Sequência visual não encontrada: " + sequence_name)
		sequence_finished.emit(sequence_name)
		return

	print("Sequência encontrada:", sequence.sequence_name)
	print("Quantidade de steps:", sequence.steps.size())

	await _play_sequence(player, sequence)
	sequence_finished.emit(sequence_name)

func _play_sequence(player: Player, sequence: VisualSequenceData) -> void:
	if not sequence:
		return

	for step in sequence.steps:
		_apply_step(player, step)
		await _handle_step_flow(player, step)

func _apply_step(player: Player, step: VisualSequenceStepData) -> void:
	if not step:
		push_warning("Step inválido na sequência.")
		return

	print("Aplicando step:", step.resource_path)

	player.visual_library.apply_sequence_step(step)
		
		
func _handle_step_flow(player: Player, step: VisualSequenceStepData) -> void:
	if step.wait_until_on_floor:
		while not player.is_on_floor():
			await get_tree().process_frame

	if step.wait_for_completion:
		await player.sprite.animation_finished

	if step.custom_delay > 0.0:
		await get_tree().create_timer(step.custom_delay).timeout

func _play_if_exists(sprite: AnimatedSprite2D, animation_name: String) -> void:
	if not sprite.sprite_frames:
		return

	if not sprite.sprite_frames.has_animation(animation_name):
		return

	sprite.stop()
	sprite.frame = 0
	await get_tree().process_frame
	sprite.play(animation_name)
	await sprite.animation_finished
