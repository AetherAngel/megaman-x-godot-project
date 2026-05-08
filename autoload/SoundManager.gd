# autoload/SoundManager.gd
extends Node

const SOUNDS_JSON := "res://resources/sounds/sounds.json"
const MUSIC_PATH  := "res://resources/sounds/stage/"
const SFX_PATH    := "res://resources/sounds/sfx/"

var _db: Dictionary          = {} # Dados do JSON
var sound_cache: Dictionary  = {}
var _pending_loops: Dictionary = {}   # id → true, enquanto aguarda o one-shot

# ── Volumes master (em dB) ───────────────────────────────────
# Hierarquia: MasterVolume → StageMasterVolume
#                          → SFXMasterVolume
# Cada bus interno ainda opera com seu próprio volume relativo.
# Alterar o master muda todos de uma vez.
var _master_volume_db:  float = 0.0
var _stage_volume_db:   float = 0.0
var _sfx_volume_db:     float = 0.0

# ── Players fixos ────────────────────────────────────────────
@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var sfx_player:   AudioStreamPlayer = AudioStreamPlayer.new()
# SFX ativos (multi instância)
var _active_sfx: Dictionary = {} # id -> Array[AudioStreamPlayer]

# Loop players: sfx_id → AudioStreamPlayer
var _loop_players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	add_child(sfx_player)
	music_player.bus = "Music"
	sfx_player.bus   = "SFX"
	_load_db()


# ============================================================
# VOLUME MASTER HIERARCHY
#
# AudioServer buses usados:
#   "Master" → controlado por set_master_volume()
#   "Music"  → controlado por set_stage_volume()  (filho do Master)
#   "SFX"    → controlado por set_sfx_volume()    (filho do Master)
#
# set_master_volume() move o bus Master — afeta tudo.
# set_stage_volume() e set_sfx_volume() são relativos ao Master.
# ============================================================

func set_master_volume(db: float) -> void:
	_master_volume_db = db
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func set_stage_volume(db: float) -> void:
	_stage_volume_db = db
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func set_sfx_volume(db: float) -> void:
	_sfx_volume_db = db
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func mute_all(muted: bool) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)


func get_master_volume() -> float: return _master_volume_db
func get_stage_volume()  -> float: return _stage_volume_db
func get_sfx_volume()    -> float: return _sfx_volume_db


# ============================================================
# LOAD
# ============================================================

func _load_db() -> void:
	var file := FileAccess.open(SOUNDS_JSON, FileAccess.READ)
	if not file:
		push_error("❌ sounds.json não encontrado: " + SOUNDS_JSON)
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("❌ Erro ao parsear sounds.json — linha %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	_db = json.data
	print("✅ sounds.json carregado — %d músicas, %d sfx" % [
		_db["music"].size(), _db["sfx"].size()
	])



# ============================================================
# MÚSICA
# ============================================================

func play_music(id: String, volume_override: float = INF) -> void:
	if not _db["music"].has(id):
		push_error("⚠️ Música não registrada no JSON: " + id)
		return
	var entry: Dictionary = _db["music"][id]
	var path: String = MUSIC_PATH + entry["file"]
	var volume: float = entry["volume_db"] if volume_override == INF else volume_override

	if not sound_cache.has(path):
		if ResourceLoader.exists(path):
			sound_cache[path] = load(path)
		else:
			push_error("⚠️ Arquivo de música não encontrado: " + path)
			return

	music_player.stream    = sound_cache[path]
	music_player.volume_db = volume
	music_player.play()


func play_stage_music(stage_id: String) -> void:
	if not _db["stage_music"].has(stage_id):
		push_error("⚠️ Stage sem música no JSON: " + stage_id)
		return
	play_music(_db["stage_music"][stage_id])


func stop_music() -> void:
	music_player.stop()


# ============================================================
# SFX — one-shot
# ============================================================

func play_sfx(id: String, volume_override: float = INF, pitch_override: float = INF) -> void:
	if not _db["sfx"].has(id):
		push_error("⚠️ SFX não registrado no JSON: " + id)
		return
	var entry: Dictionary  = _db["sfx"][id]
	var path: String   = SFX_PATH + entry["file"]
	var volume: float = entry["volume_db"] if volume_override == INF else volume_override
	var pitch: float  = entry["pitch"]     if pitch_override  == INF else pitch_override
	var stream := _load_stream(path)
	if not stream:
		return
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream      = stream
	player.volume_db   = volume
	player.pitch_scale = pitch
	player.bus         = "SFX"
	# 🔥 registra o player
	if not _active_sfx.has(id):
		_active_sfx[id] = []

	_active_sfx[id].append(player)
	
	
	player.play()
	await player.finished
	
	# 🔥 remove quando terminar
	if _active_sfx.has(id):
		_active_sfx[id].erase(player)
		if _active_sfx[id].is_empty():
			_active_sfx.erase(id)
	player.queue_free()


func stop_sfx(id: String) -> void:
	if not _active_sfx.has(id):
		push_error("⚠️ stop_sfx: nenhum SFX ativo com id '%s'" % id)
		return
	
	var players: Array = _active_sfx[id]
	var any_stopped := false
	
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
			any_stopped = true
	
	_active_sfx.erase(id)
	
	if not any_stopped:
		push_error("⚠️ stop_sfx: id '%s' encontrado, mas nenhum player válido estava ativo" % id)

func stop_all_sfx() -> void:
	for id in _active_sfx.keys():
		stop_sfx(id)


# ============================================================
# SFX — LOOP
#
# Como o MMX resolve o loop do charge:
#   O áudio de charge tem duas partes: intro e sustain.
#   No JSON, você pode definir "loop_begin_sec" no entry do sfx.
#   Quando > 0, o SoundManager configura o AudioStreamWAV para
#   fazer loop a partir daquele ponto em vez do início,
#   dando a sensação de "intro + loop do tail" exatamente como
#   no SNES/PSX.
#
#   No sounds.json:
#     "charging_shot": { "file": "charging_shot.wav",
#                        "volume_db": -10.0, "pitch": 1.0,
#                        "loop_begin_sec": 0.45 }
#
#   Se loop_begin_sec = 0 ou ausente, o loop inteiro é repetido
#   do começo (comportamento padrão).
# ============================================================

# ============================================================
# LOOP GENÉRICO — funciona com qualquer id do JSON (sfx ou music)
#
# Auto-detecta a categoria pelo id: procura em "sfx" primeiro,
# depois em "music". Usa o bus correto de cada categoria.
#
# Sobre loop_begin_sec (MMX-style):
#   O player inicia a reprodução JÁ em loop_begin_sec via play(from_position).
#   Não há intro — o som começa direto no ponto do loop.
#   Se loop_begin_sec = 0, começa do início normalmente.
# ============================================================

func play_loop(id: String, volume_override: float = INF, pitch_override: float = INF, loop_begin_sec_override: float = -1.0) -> void:
	# Já existe loop desse id rodando — ignora.
	if _loop_players.has(id) and is_instance_valid(_loop_players[id]):
		return

	var resolved: Dictionary = _resolve_sound(id)
	if resolved.is_empty():
		push_error("⚠️ play_loop: id '%s' não encontrado em nenhuma categoria do JSON." % id)
		return

	var entry: Dictionary = resolved["entry"]
	var volume: float = entry["volume_db"] if volume_override == INF else volume_override
	var pitch: float  = entry.get("pitch", 1.0) if pitch_override == INF else pitch_override

	# Resolve o loop_begin_sec: override do resource → JSON → 0.0
	var loop_begin_sec: float
	if loop_begin_sec_override >= 0.0:
		loop_begin_sec = loop_begin_sec_override
	else:
		loop_begin_sec = entry.get("loop_begin_sec", 0.0)

	var stream: AudioStream = _load_stream(resolved["path"])
	if not stream:
		return

	# Duplica antes de configurar — nunca modifica o stream do cache.
	stream = _configure_wav_loop(stream.duplicate(), loop_begin_sec)

	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream      = stream
	player.volume_db   = volume
	player.pitch_scale = pitch
	player.bus         = resolved["bus"]

	# Começa JÁ em loop_begin_sec — sem intro, sem esperar o fim do arquivo.
	# player.play(from_position) pula direto para o ponto do loop.
	player.play(loop_begin_sec)

	_loop_players[id] = player


# stop_loop já cancela o pending também
func stop_loop(id: String) -> void:
	_pending_loops.erase(id)   # ← cancela o play_then_loop se ainda aguardando
	if not _loop_players.has(id):
		return
	var player: AudioStreamPlayer = _loop_players[id]
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
	_loop_players.erase(id)

func stop_all_loops() -> void:
	for id: String in _loop_players.keys().duplicate():
		stop_loop(id)


# ── Resolve entry + path + bus para qualquer id do JSON ──────
func _resolve_sound(id: String) -> Dictionary:
	if _db["sfx"].has(id):
		var entry: Dictionary = _db["sfx"][id]
		return { "entry": entry, "path": SFX_PATH + entry["file"], "bus": "SFX" }
	if _db["music"].has(id):
		var entry: Dictionary = _db["music"][id]
		return { "entry": entry, "path": MUSIC_PATH + entry["file"], "bus": "Music" }
	return {}


# ── Configura loop point no AudioStreamWAV e retorna o stream ─
# Recebe sempre um duplicate() — nunca toca no stream do cache.
# loop_begin_sec define onde o audio reinicia ao chegar no fim.
func _configure_wav_loop(stream: AudioStream, loop_begin_sec: float) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode  = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = int(loop_begin_sec * wav.mix_rate) if loop_begin_sec > 0.0 else 0
		wav.loop_end   = int(wav.get_length() * wav.mix_rate)
	return stream


# ============================================================
# HELPERS
# ============================================================

func _load_stream(path: String) -> AudioStream:
	if not sound_cache.has(path):
		if ResourceLoader.exists(path):
			sound_cache[path] = load(path)
		else:
			push_error("⚠️ Arquivo de áudio não encontrado: " + path)
			return null
	return sound_cache[path]

# Toca um sfx uma vez e, ao terminar, entra em loop automaticamente.
# Se stop_loop(id) for chamado antes do sfx terminar, o loop não inicia.
func play_then_loop(id: String, volume_override: float = INF, 
				   pitch_override: float = INF, loop_begin_sec_override: float = -1.0) -> void:
	# Evita duplicata se já tem um ciclo desse id em andamento
	if _loop_players.has(id) or _pending_loops.has(id):
		return
	
	_pending_loops[id] = true
	await play_sfx(id, volume_override, pitch_override)
	
	# Só entra no loop se não foi cancelado enquanto aguardava
	if _pending_loops.has(id):
		_pending_loops.erase(id)
		play_loop(id, volume_override, pitch_override, loop_begin_sec_override)





# Atalhos rápidos
func play_jump()          -> void: play_sfx("jump")
func play_shoot()         -> void: play_sfx("shoot")
func play_dash()          -> void: play_sfx("dash")
func play_land()          -> void: play_sfx("land")
func play_hurt()          -> void: play_sfx("hurt")
func play_confirmbutton() -> void: play_sfx("snd_player_success")
func play_playerready()   -> void: play_sfx("snd_ready")
