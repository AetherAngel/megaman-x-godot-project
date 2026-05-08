# player_select.gd
extends Control

var selected_index: int = 0
var characters = ["X", "Zero", "Axl"]

@onready var background = $Background
@onready var character_display = $CharacterDisplay
@onready var hbox = $HBoxContainer

func _ready() -> void:
	
	
	print("=== DEBUG PLAYER SELECT ===")
	print("Background: ", background != null)
	print("CharacterDisplay: ", character_display != null)
	
	# Força máxima de visibilidade
	if background:
		background.visible = true
		background.modulate = Color(1, 1, 1, 1)
		background.z_index = 0
	
	if character_display:
		character_display.visible = true
		character_display.modulate = Color(1, 1, 1, 1)
		character_display.z_index = 10
		character_display.scale = Vector2(1.0, 1.0)
		character_display.set_anchors_preset(Control.PRESET_CENTER)  # ✅
		
	update_selection()
	print("Player Select carregado")

func _input(event: InputEvent) -> void:
	if GameManager.current_input_mode != GameManager.InputMode.MENU:
		return

	if event.is_action_pressed("move_left"):
		selected_index = (selected_index - 1 + 3) % 3
		update_selection()

	elif event.is_action_pressed("move_right"):
		selected_index = (selected_index + 1) % 3
		update_selection()

	elif event.is_action_pressed("shoot"):
		confirm_selection()

func update_selection() -> void:
	if hbox:
		for i in hbox.get_child_count():
			var box = hbox.get_child(i)
			if box:
				if i == selected_index:
					box.modulate = Color(1.5, 1.5, 1.5, 1.0)
					box.scale = Vector2(1.3, 1.3)
				else:
					box.modulate = Color(0.8, 0.8, 0.8, 0.9)
					box.scale = Vector2(1.0, 1.0)

	# Força atualização do personagem
	if character_display:
		var char_name = characters[selected_index].to_lower()
		var path = "res://sprites/spr_player_" + char_name + "/select.png"
		
		if ResourceLoader.exists(path):
			character_display.texture = load(path)
			print("✅ Mostrando: " + char_name)
		else:
			print("⚠️ Imagem não encontrada: " + path)

func confirm_selection() -> void:
	var chosen = characters[selected_index]
	print("✅ Confirmado: " + chosen)

	SoundManager.play_sfx("snd_player_success", -25.0)
	GameManager.current_player = chosen

	# ✅ Usa change_state em vez de start_stage diretamente
	GameManager.change_state(GameManager.GameState.IN_STAGE)
