# menu/MainMenu.gd
extends Node

## Aquece (pré-carrega) os recursos que causam engasgo de FPS na primeira
## vez que são usados durante o gameplay. Roda uma vez ao entrar no Main
## Menu — se vai engasgar, engasga aqui, numa tela estática, e não durante
## o jogo.
##
## TRÊS CAUSAS CONFIRMADAS DO ENGASGO (todas usam load() em vez de preload(),
## então só pagam o custo de disco/GPU na primeira vez que a linha roda):
##
##   1. PlayerCharacterData.get_default_armor() — fallback load(ArmorData)
##      → engasgo na primeira troca de personagem
##   2. Player._load_skin_swap() — load(SpriteFrames) por animation set
##      → engasgo na primeira transição de estado (Jump, Dash, Land...)
##   3. ChargeSystem._fire()/_fire_stock() + BusterLayer._apply_buster_visual()
##      → engasgo no primeiro tiro (carrega o projétil E o sprite do buster)
##
## Por que aquecer TODOS os personagens do roster, não só o selecionado:
##   O jogador pode trocar de personagem DURANTE o stage (CharacterManagement
##   já suporta isso). Aquecer só quem foi selecionado no Player_Select
##   deixaria o OUTRO personagem com o mesmo engasgo na primeira troca.


## Sets de animação comuns o suficiente para aquecer sempre.
## Cobre os states mais usados no gameplay normal.
## TODO: expandir esta lista se outros sets (ex: combo do sabre, técnicas
## específicas) continuarem engasgando na primeira vez — ver README.
const COMMON_ANIM_SETS: Array[String] = [
	"idle", "run", "jump", "dash", "land", "fall",
]

## Projéteis hardcoded em ChargeSystem._fire()/_fire_stock() via
## match GameManager.current_player. Mantido explícito aqui por ora.
## TODO: migrar para WeaponData.projectile_scene (referência direta de
## Resource) quando o ChargeSystem for desacoplado do match por string —
## nesse momento este array fixo deixa de ser necessário.
const PROJECTILE_PATHS: Array[String] = [
	"res://player/projectiles/ZeroProjectile.tscn",
	"res://player/objects/projectiles/XProjectile.tscn",
	"res://player/objects/projectiles/Fourth_Projectile.tscn",
]


func _ready() -> void:
	_warmup_characters()
	_warmup_projectiles()
	print("[MainMenu] Aquecimento de recursos concluído.")


# ─────────────────────────────────────────────────────────────
# WARMUP — personagens (armadura + animation sets)
# ─────────────────────────────────────────────────────────────

func _warmup_characters() -> void:
	# CharacterManagement já está populado neste ponto — autoloads
	# rodam seu _ready() antes de qualquer cena do jogo.
	for char_data in CharacterManagement.get_roster():
		# Causa #1 — ArmorData via fallback load().
		var armor: ArmorData = char_data.get_default_armor()
		if not armor:
			push_warning("[MainMenu] Sem armadura para '%s' — pulando warmup de animações." % char_data.character_id)
			continue

		# Causa #2 — SpriteFrames por animation set.
		var folder: String = char_data.base_folder
		if not armor.animation_folder_override.is_empty():
			folder = armor.animation_folder_override

		for action in COMMON_ANIM_SETS:
			var path := "res://resources/animations/" + folder + "_" + action + ".tres"
			if ResourceLoader.exists(path):
				load(path)


# ─────────────────────────────────────────────────────────────
# WARMUP — projéteis (causa #3)
# ─────────────────────────────────────────────────────────────

func _warmup_projectiles() -> void:
	for path in PROJECTILE_PATHS:
		if ResourceLoader.exists(path):
			load(path)
		else:
			push_warning("[MainMenu] Projétil não encontrado para warmup: %s" % path)
