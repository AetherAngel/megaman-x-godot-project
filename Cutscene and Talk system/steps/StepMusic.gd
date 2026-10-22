# talksystem/steps/StepMusic.gd
class_name StepMusic
extends CutsceneStep

## Troca ou para a música atual.

enum Action { PLAY, STOP }

## PLAY = troca a música atual por music_id. STOP = para a música.
@export var action: Action = Action.PLAY
## ID da música no sounds.json (seção "music"). Só para PLAY.
@export var music_id: String = ""
## Volume em dB. INF = usa o do JSON.
@export var volume: float = INF
