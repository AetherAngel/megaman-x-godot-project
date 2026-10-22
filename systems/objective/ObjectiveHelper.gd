# systems/objective/ObjectiveHelper.gd
class_name ObjectiveHelper
extends RefCounted

## Decide o que acontece quando o jogador FALHA o objetivo (morre).
##
## É uma classe auxiliar do GameManager: ele cria a instância e delega para ela
## (GameManager.on_player_failed). Assim o GameManager não acumula a lógica de
## cada tipo de falha, e o Player só precisa conhecer o GameManager.
##
## Recebe o contexto por parâmetro (estado, fase e árvore) em vez de guardar
## referências — sem estado próprio, fácil de entender e de estender.
##
## Falhas tratadas:
##   IN_STAGE   → reinicia a música da fase.
##   BOSS_FIGHT → reseta a luta (boss e arena), volta ao IN_STAGE sem recarregar
##                a cena e reinicia a música da fase. O fluxo do boss recomeça
##                quando o jogador atravessar a porta de novo.
## Outros estados → só avisa no Output (nada foi pedido para eles ainda).
##
## Vitória: on_boss_defeated() marca a fase como concluída, libera as armas e salva.

## Grupo das peças da arena que precisam voltar ao estado inicial (porta, gatilho).
## Cada uma implementa reset_arena().
const ARENA_GROUP := &"arena_resettable"


## Chamado quando o Player morre, no meio do fade (tela preta), antes do respawn.
func on_player_failed(state: GameManager.GameState, stage_id: String, tree: SceneTree) -> void:
	match state:
		GameManager.GameState.IN_STAGE:
			_restart_stage_music(stage_id)
		GameManager.GameState.BOSS_FIGHT:
			_fail_boss_fight(stage_id, tree)
		_:
			push_warning("[ObjectiveHelper] Falha em estado sem tratamento: %s" % GameManager.GameState.keys()[state])


# ── Vitória ──────────────────────────────────────────────────

## Chamado quando o jogador derrota o boss da fase.
## Marca a fase como concluída, libera a recompensa (X: arma especial, Zero: técnica —
## os dois de uma vez, pelo mesmo weapon_id) e salva no slot atual.
func on_boss_defeated(stage_id: String, reward: WeaponRewardData) -> void:
	var data := SaveSystem.current_save
	if not data:
		push_warning("[ObjectiveHelper] Sem save ativo — vitória não registrada.")
		return

	if not stage_id.is_empty():
		data.defeated_bosses[stage_id] = true

	if reward and not reward.weapon_id.is_empty() and not data.unlocked_weapons.has(reward.weapon_id):
		data.unlocked_weapons.append(reward.weapon_id)

	SaveSystem.save()


# ── Boss ─────────────────────────────────────────────────────

func _fail_boss_fight(stage_id: String, tree: SceneTree) -> void:
	BossFlowManager.abort_fight()
	GameManager.resume_stage()
	tree.call_group(ARENA_GROUP, "reset_arena")
	SoundManager.stop_all_loops()
	_restart_stage_music(stage_id)


# ── Música ───────────────────────────────────────────────────

## O SoundManager.play_music sempre reinicia a faixa do começo, e o GameManager
## guarda a fase atual — então reiniciar a música da fase é só pedir de novo.
func _restart_stage_music(stage_id: String) -> void:
	if stage_id.is_empty():
		return
	SoundManager.play_stage_music(stage_id)
