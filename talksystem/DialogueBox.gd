# talksystem/DialogueBox.gd
extends Control

@onready var mugshot_left:  TextureRect   = $MugshotLeft
@onready var mugshot_right: TextureRect   = $MugshotRight
@onready var speaker_label: Label         = $TextContainer/SpeakerLabel
@onready var text_label:    RichTextLabel = $TextContainer/TextLabel
@onready var continue_icon: Control       = $ContinueIcon

var _debug_printed: bool = false

const DIM_MODULATE  = Color(0.4, 0.4, 0.4, 1.0)
const FULL_MODULATE = Color(1.0, 1.0, 1.0, 1.0)

var _typewriter_timer: float = 0.0
var _char_speed: float = 0.03
var _target_text: String = ""
var _current_chars: int = 0
var _typing: bool = false


func _ready() -> void:
	visible = false
	TalkManager.register_box(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	if continue_icon:
		continue_icon.visible = false
	call_deferred("_setup_layout")


func _fit_to_viewport() -> void:
	var vp = get_viewport().get_visible_rect().size
	const BOX_H: float = 80.0      # um pouco mais de altura pra respirar
	const MARGIN: float = 8.0     # margem da parte de baixo (mais comum em jogos retro)
	const BOX_W_RATIO: float = 0.65 # largura confortável (ajuste se quiser)

	var box_w = vp.x * BOX_W_RATIO
	
	set_size(Vector2(box_w, BOX_H))
	# Ancoragem na parte inferior da tela (como na maioria dos Mega Man)
	set_position(Vector2((vp.x - box_w) / 2.0, vp.y - BOX_H - MARGIN))


func _setup_layout() -> void:
	const MUG:   float = 32.0   # mugshot maior
	const PAD:   float = 5.0
	const BOX_H: float = 10.0
	var box_w = size.x

	var panel = $Panel
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0; panel.offset_top = 0
	panel.offset_right = 0; panel.offset_bottom = 0

	# MugshotLeft — fora da caixa à esquerda, sobrepondo a borda
	var mug_y = (BOX_H - MUG) / 2.0
	mugshot_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mugshot_left.position     = Vector2(-MUG * 0.4, mug_y)  # sobrepõe levemente
	mugshot_left.size         = Vector2(MUG, MUG)
	mugshot_left.expand_mode  = TextureRect.EXPAND_KEEP_SIZE
	mugshot_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# MugshotRight — fora da caixa à direita, sobrepondo a borda
	mugshot_right.anchor_left   = 1.0
	mugshot_right.anchor_right  = 1.0
	mugshot_right.anchor_top    = 0.0
	mugshot_right.anchor_bottom = 0.0
	mugshot_right.offset_left   = -MUG * 0.7   # sobrepõe a borda direita
	mugshot_right.offset_right  = MUG * 0.3
	mugshot_right.offset_top    = mug_y
	mugshot_right.offset_bottom = mug_y + MUG
	mugshot_right.expand_mode   = TextureRect.EXPAND_KEEP_SIZE
	mugshot_right.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# TextContainer — área central com padding para não bater nos mugshots
	var text_x = MUG * 0.4 + PAD
	var text_w = box_w - (MUG * 0.4) - (MUG * 0.4) - (PAD * 2)
	var vbox = $TextContainer
	vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(text_x, PAD)
	vbox.size     = Vector2(text_w, BOX_H + 80.0 - PAD * 2)
	vbox.add_theme_constant_override("separation", 4)

	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_label.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	speaker_label.clip_text             = true

	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	text_label.fit_content           = false
	text_label.scroll_active         = false
	text_label.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	text_label.clip_contents         = true


func _process(delta: float) -> void:
	if not _debug_printed and visible:
		_debug_printed = true
		_print_layout_debug()
	if not _typing:
		return
	_typewriter_timer += delta
	while _typewriter_timer >= _char_speed and _current_chars < _target_text.length():
		_typewriter_timer -= _char_speed
		_current_chars += 1
		text_label.text = _target_text.substr(0, _current_chars)
		SoundManager.play_sfx("snd_text")
	if _current_chars >= _target_text.length():
		_typing = false
		TalkManager._is_typing = false
		if continue_icon:
			continue_icon.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		return
	if event.is_action_pressed("shoot") or event.is_action_pressed("jump"):
		TalkManager.on_advance_pressed()
		get_viewport().set_input_as_handled()


func set_speaker(speaker_name: String, mugshot_tex: Texture2D, player_is_speaker: bool) -> void:
	speaker_label.text = speaker_name

	if player_is_speaker:
		# Player à esquerda — esconde direita se não houver NPC
		mugshot_left.modulate  = FULL_MODULATE
		mugshot_right.modulate = DIM_MODULATE
		if mugshot_tex:
			mugshot_left.texture  = mugshot_tex
			mugshot_left.visible  = true
		else:
			mugshot_left.visible  = false
		# Direita só aparece se tiver textura setada previamente
		# (mantém visível se já tinha mugshot do NPC)
	else:
		# NPC à direita — esconde esquerda se não houver player falando
		mugshot_right.modulate = FULL_MODULATE
		mugshot_left.modulate  = DIM_MODULATE
		if mugshot_tex:
			mugshot_right.texture = mugshot_tex
			mugshot_right.visible = true
		else:
			mugshot_right.visible = false
		mugshot_left.visible = false  # player não fala, esconde esquerda

	_recalculate_text_area()
	

func _recalculate_text_area() -> void:
	const MUG: float = 32.0
	const PAD: float = 5.0
	const BOX_H: float = 80.0

	var left_space  = (MUG * 0.4 + PAD) if mugshot_left.visible  else PAD
	var right_space = (MUG * 0.4 + PAD) if mugshot_right.visible else PAD

	var vbox = $TextContainer
	vbox.position = Vector2(left_space, PAD)
	vbox.size     = Vector2(size.x - left_space - right_space, BOX_H + 15.0 - PAD * 2)

func start_typewriter(full_text: String, char_speed: float) -> void:
	_target_text      = full_text
	_char_speed       = char_speed
	_current_chars    = 0
	_typewriter_timer = 0.0
	_typing           = true
	text_label.text   = ""
	if continue_icon:
		continue_icon.visible = false


func complete_text(full_text: String) -> void:
	_typing         = false
	_current_chars  = full_text.length()
	text_label.text = full_text
	if continue_icon:
		continue_icon.visible = true


func _print_layout_debug() -> void:
	print("=== DIALOGUE BOX DEBUG ===")
	print("DialogueBox size: ", size, " pos: ", position)
	print("Panel size: ", $Panel.size)
	print("MugshotLeft size: ", mugshot_left.size, " pos: ", mugshot_left.position)
	print("MugshotRight size: ", mugshot_right.size, " offsets: ", mugshot_right.offset_left, " / ", mugshot_right.offset_right)
	print("TextContainer size: ", $TextContainer.size, " pos: ", $TextContainer.position)
	print("SpeakerLabel size: ", speaker_label.size)
	print("TextLabel size: ", text_label.size)
	print("==========================")
