# systems/hit/HitComponent.gd
class_name HitComponent
extends Node

## Componente reutilizável que descreve um hit e o reporta ao HitBus.
## Adicione como FILHO do objeto que causa o hit (projétil, espinhos, área de contato).
##
## Os três papéis do hit:
##   attacker : a entidade responsável pelo evento (ex: o Boss que lançou o Hadouken).
##   source   : o objeto que originou o hit (ex: o próprio projétil). É o pai deste nó.
##   target   : quem foi atingido — informado em report().
## Esses papéis podem ser o mesmo objeto: em espinhos, attacker e source são os espinhos.
##
## Este componente NÃO detecta colisão por conta própria, exceto com auto_report.
## Cada caso (projétil, espinho, contato) continua tendo seu mecanismo de detecção
## e chama report(target) quando decidir que houve hit.
##
## MODOS DO auto_report (report_mode):
##   ON_ENTER   : reporta UMA vez quando o corpo entra na área (comportamento original).
##                Ideal para projéteis, que somem ao acertar.
##   CONTINUOUS : o corpo fica registrado enquanto estiver dentro da área e o hit é
##                reportado de novo assim que o alvo puder levar dano (fim dos i-frames).
##                Ideal para hazards que permanecem na cena (lava, pilar, espinhos).
##                Salvaguarda: antes de cada hit confirma que o corpo ainda está
##                sobreposto à área — quem saiu a tempo não leva dano.
##                Custo: o _physics_process só fica ligado enquanto há alguém dentro.

enum ReportMode { ON_ENTER, CONTINUOUS }

## Dano bruto (raw). Quem recebe decide o que fazer com ele:
##   alvo SEM DamageResistanceTable (Player, inimigo comum) → vira unidades de dano.
##   alvo COM tabela (Boss)                                 → a tabela decide pelo tipo.
@export var damage: float = 0.0

## Tipo do dano. Use as constantes de DamageType (BUSTER, FIRE, CONTACT...).
## É a chave consultada na DamageResistanceTable do Boss.
@export var damage_type_id: StringName = DamageType.CONTACT

## Tag lida pelo Boss para imunidades por fase (BossPhaseData.immune_to).
## Vazio = sem tag.
@export var damage_tag: String = ""

## Se true e o pai for uma Area2D, conecta body_entered → report() automaticamente.
## Pensado para espinhos, poços e áreas de contato, que não precisam de script próprio.
## Projéteis, que já têm handler próprio, chamam report() manualmente.
@export var auto_report: bool = false

## Como o auto_report se comporta. Só vale com auto_report ligado.
## O padrão (ON_ENTER) mantém o comportamento de sempre.
@export var report_mode: ReportMode = ReportMode.ON_ENTER

## Só no modo CONTINUOUS: intervalo, em segundos, entre as verificações.
## 0 = a cada frame de física. Valores maiores (ex: 0.05) aliviam hazards com muitos alvos.
## A cadência real do dano nunca é menor que os i-frames do alvo.
@export_range(0.0, 1.0, 0.01, "suffix:s") var recheck_interval: float = 0.0

## Quem causou o hit. Atribuído por quem spawna o objeto (ex: ChargeSystem, Boss).
## Se ninguém atribuir, get_attacker() devolve o próprio source.
var attacker: Node = null

## O objeto que originou o hit (o pai deste componente).
var source: Node = null

var _area: Area2D = null
## Corpos dentro da área (modo CONTINUOUS). Sem tipo de propósito: um corpo
## liberado da memória não pode ser atribuído a uma variável tipada.
var _inside: Array = []
var _recheck_timer: float = 0.0


func _ready() -> void:
	source = get_parent()

	# O loop do modo CONTINUOUS só liga quando alguém entra na área.
	set_physics_process(false)

	if not auto_report:
		if report_mode == ReportMode.CONTINUOUS:
			push_warning("[HitComponent] report_mode CONTINUOUS exige auto_report ligado: '%s'" % source.name)
		return

	var area := source as Area2D
	if not area:
		push_warning("[HitComponent] auto_report exige que o pai seja uma Area2D: '%s'" % source.name)
		return

	_area = area
	area.body_entered.connect(_on_auto_body_entered)
	if report_mode == ReportMode.CONTINUOUS:
		area.body_exited.connect(_on_auto_body_exited)


func _physics_process(delta: float) -> void:
	if recheck_interval > 0.0:
		_recheck_timer -= delta
		if _recheck_timer > 0.0:
			return
		_recheck_timer = recheck_interval

	# De trás pra frente para poder remover corpos inválidos durante o loop.
	for i in range(_inside.size() - 1, -1, -1):
		var body: Variant = _inside[i]
		if not is_instance_valid(body):
			_inside.remove_at(i)
			continue
		_try_report(body)

	if _inside.is_empty():
		set_physics_process(false)


# ─────────────────────────────────────────────────────────────
# API PÚBLICA
# ─────────────────────────────────────────────────────────────

## Notifica o HitBus de que este hit atingiu `target`.
func report(target: Node) -> void:
	HitBus.dispatch(self, target)


## Quem causou o hit. Cai para o source se o attacker não foi atribuído
## (ou já foi liberado da memória).
func get_attacker() -> Node:
	return attacker if is_instance_valid(attacker) else source


## Lidos por Player.take_damage() e Boss.take_damage() através do inflicter.
func get_damage_type_id() -> StringName:
	return damage_type_id


func get_damage_tag() -> String:
	return damage_tag


# ─────────────────────────────────────────────────────────────
# INTERNO
# ─────────────────────────────────────────────────────────────

func _on_auto_body_entered(body: Node2D) -> void:
	if report_mode == ReportMode.ON_ENTER:
		report(body)
		return

	# CONTINUOUS: cenário e paredes (sem take_damage) não precisam ser vigiados.
	if not body.has_method("take_damage"):
		return

	if not _inside.has(body):
		_inside.append(body)
	_recheck_timer = 0.0
	set_physics_process(true)
	_try_report(body)  # se já puder levar dano, não espera o próximo tick


func _on_auto_body_exited(body: Node2D) -> void:
	_inside.erase(body)
	if _inside.is_empty():
		set_physics_process(false)


## Reporta o hit só se ele realmente puder acontecer agora.
## Pular um alvo aqui NÃO descarta nada: ele continua registrado e é
## reavaliado no próximo tick (é assim que a "espera dos i-frames" funciona).
func _try_report(body: Variant) -> void:
	if not is_instance_valid(body):
		return

	# Alvo morto não deve continuar levando hit (ex: Player na cutscene de morte).
	if body.has_method("has_health") and not body.has_health():
		return

	# Nos i-frames o take_damage() do alvo descartaria o hit; só espera.
	if body.has_method("is_invulnerable") and body.is_invulnerable():
		return

	# Salvaguarda: quem já saiu da área (ou foi deixado pra trás por uma
	# hitbox que encolheu) não leva dano.
	if is_instance_valid(_area) and not _area.overlaps_body(body):
		return

	report(body)
