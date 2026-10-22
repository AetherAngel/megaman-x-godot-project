# talksystem/DialogueLine.gd
class_name DialogueLine
extends Resource

@export var speaker: String = ""          # "DrLight", "X", "Zero" — nome do mugshot sem extensão
@export var text: String = ""             # texto a exibir
@export var mugshot: String = ""          # ex: "drlight_placeholder" — sem path, sem extensão
@export var auto_advance: bool = false    # avança sozinho sem apertar botão
@export var auto_advance_delay: float = 2.0  # segundos antes de avançar
