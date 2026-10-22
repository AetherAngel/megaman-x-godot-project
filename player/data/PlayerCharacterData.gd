# player/data/PlayerCharacterData.gd
class_name PlayerCharacterData
extends Resource

## Ficha de dados de um personagem jogável.
## É a fonte de verdade para identidade, capacidades e configuração de HP do personagem.
##
## IMPORTANTE sobre skill_tree:
##   Atribua skill_tree diretamente no editor (.tres), NUNCA em runtime.
##   Atribuir em runtime muta o Resource compartilhado em memória —
##   qualquer outro sistema que referenciar esta ficha verá a skill_tree errada.


# ── Identity ──────────────────────────────────────────────────
## Chave única. Usada por CharacterManagement e HPRegistry.
## StringName para lookup O(1) em Dictionary.
## .tres existentes com character_id = "Zero" carregam corretamente.
@export var character_id: StringName = &"X"
@export var display_name: String = "Mega Man X"
@export var base_folder: String = "spr_x"


# ── HP ────────────────────────────────────────────────────────
## Unidades base de HP ao iniciar a stage. MMX original: 16.
## Mantido por compatibilidade — hp_data abaixo é a fonte de verdade real.
@export var base_hp_units: int = 16
 
## Configuração completa de HP deste personagem.
## Cada ficha (x_character.tres, zero_character.tres) tem a sua própria —
## permite X ter unit_cap=32/heart_tank_bonus=2 e um personagem futuro
## ter valores diferentes, sem tocar em nenhum código.
##
## Crie um .tres por personagem em res://player/data/hp/:
##   x_hp_data.tres, zero_hp_data.tres
@export var hp_data: HPSystemData


# ── Death ─────────────────────────────────────────────────────
## Cutscene tocada quando o HP chega a zero (efeito/animação, fade, respawn).
## Cada personagem tem a sua: a animação de morte difere entre X, Zero...
## Sem ela, o Player só reaparece direto (com aviso no Output).
@export var death_cutscene: CutsceneData
## Efeito spawnado no ponto da morte (ex: anel de orbes). O Player copia este valor
## para Actor.death_effect, que já o spawna sozinho no zero_health. Cada personagem
## tem o seu (arte e cor diferentes). A ficha manda: vazio = sem efeito.
@export var death_effect: SpawnedParticleDef


# ── Victory ───────────────────────────────────────────────────
## Cutscene do Player depois de derrotar um boss: o state Victory toca a pose
## (VisualSequence "Victory") e esta cutscene faz a saída (ex: VisualSequence "Outro" via
## StepAnimation no grupo "player", fade...). Cada personagem tem a sua.
@export var victory_cutscene: CutsceneData


# ── Armor ─────────────────────────────────────────────────────
## Nome da armadura padrão — usado para montar o path de fallback.
@export var armor_name: String = "armor_normal"
## Referência direta à ArmorData (preferencial).

## Se null, get_default_armor() usa armor_name como fallback de path.
@export var default_armor: ArmorData

# ── Weapons ───────────────────────────────────────────────────
## Arma padrão do personagem: "buster" ou "saber".
## Usado por SaberAttack e SaberUnequip para identificar o tipo de combate.
@export var default_weapon: String = "buster"
## Placeholder para o WeaponSystem futuro.
## Reservado para special weapons coletadas de bosses (X) ou técnicas alternativas.
@export var special_weapon: String = "buster"

# ── Capabilities ──────────────────────────────────────────────
## Substituem todos os match/if GameManager.current_player em Player.gd.
## Adicionar personagem = criar .tres com as flags corretas. Zero código novo.
@export var has_buster: bool = true
@export var has_saber: bool = false
@export var can_air_dash: bool = false

@export var can_double_jump: bool = false
@export var can_wall_kick: bool = true



# ── Charge System ─────────────────────────────────────────────
@export var charge_input:     String = "shoot"
@export var charge_lv1_time:  float  = 0.75
@export var charge_lv2_time:  float  = 2.0
@export var charge_max_level: int    = 2
@export var has_stock:        bool   = false
@export var has_plasma:       bool   = false

# ── Buster Layer ──────────────────────────────────────────────
@export var buster_folder: String = "spr_x"

# ── Skill Tree ────────────────────────────────────────────────
## Atribua no editor. NÃO atribuir em runtime (veja aviso no topo do arquivo).
@export var skill_tree: SkillTree



# ─────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────

## Retorna a ArmorData padrão do personagem.
## Prefere default_armor (referência direta).
## Fallback: monta path a partir de armor_name e carrega do disco.
func get_default_armor() -> ArmorData:
	if default_armor != null:
		return default_armor
	var path := _build_armor_path()
	if ResourceLoader.exists(path):
		return load(path) as ArmorData
	push_error("[PlayerCharacterData] Armadura não encontrada: '%s'" % path)
	return null


func _build_armor_path() -> String:
	return "res://player/data/armors/" + armor_name + ".tres"
