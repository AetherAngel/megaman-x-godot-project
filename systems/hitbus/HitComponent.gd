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
## Este e os dois campos abaixo são a BASE: quem spawna o objeto escreve aqui. Um override
## temporário (push_override) nunca os altera — para ler o valor em vigor use get_damage(),
## get_damage_type_id() e get_damage_tag().
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

## Prioridade deste golpe numa DISPUTA SIMULTÂNEA com outro golpe do MESMO dono sobre o MESMO
## alvo (ex.: o corpo do Boss e o soco dele pegando o Player no mesmo tick): o de maior
## prioridade vale e os demais cedem. 0 = contato comum; a HitboxArea usa 10 (golpe de ataque).
## Quem já bateu antes segue valendo: os i-frames do alvo bloqueiam o resto.
@export var priority: int = 0

## Quem causou o hit. Atribuído por quem spawna o objeto (ex: ChargeSystem, Boss).
## Se ninguém atribuir, get_attacker() devolve o próprio source.
var attacker: Node = null

## O objeto que originou o hit (o pai deste componente).
var source: Node = null

var _area: Area2D = null
## Overrides temporários, do mais antigo ao mais recente; o último vale. Cada entrada:
## {"token": Object, "profile": DamageProfile}. Ver push_override().
var _overrides: Array = []
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
	if _has_higher_priority_hitbox():
		# Disputa possível. A sobreposição das áreas só fica consistente DEPOIS que todas
		# sinalizaram (quem sinaliza primeiro vê as outras desatualizadas), então a decisão
		# vai para o fim deste passo de física. Sem hitbox de maior prioridade: imediato.
		_settle_priority.call_deferred(target)
		return
	HitBus.dispatch(self, target)


## O corpo (CharacterBody2D) que carrega este golpe. O contato do Boss fica numa Area2D filha
## do corpo e não tem `attacker`; a HitboxArea tem (o próprio dono). Sobe até achar o corpo.
## Sem corpo na cadeia, cai para o attacker/source: só não há disputa de prioridade.
func get_owner_actor() -> Node:
	var start: Node = get_attacker()
	var n: Node = start
	while n != null:
		if n is CharacterBody2D:
			return n
		n = n.get_parent()
	return start


## Quem causou o hit. Cai para o source se o attacker não foi atribuído
## (ou já foi liberado da memória).
func get_attacker() -> Node:
	return attacker if is_instance_valid(attacker) else source


## Valor EM VIGOR do dano, tipo e tag: o do override mais recente, ou a base se não houver.
## O HitBus lê get_damage(); Player.take_damage() e Boss.take_damage() leem tipo e tag através
## do inflicter. Quem precisar do dano de um hit deve usar estes getters, não os campos.
func get_damage() -> float:
	var p := _top_override()
	return p.damage if p else damage


func get_damage_type_id() -> StringName:
	var p := _top_override()
	return p.damage_type_id if p else damage_type_id


func get_damage_tag() -> String:
	var p := _top_override()
	return p.damage_tag if p else damage_tag


# ─────────────────────────────────────────────────────────────
# OVERRIDE TEMPORÁRIO
# ─────────────────────────────────────────────────────────────
# Troca o dano, o tipo e a tag em vigor SEM mexer na base: restaurar é só remover a entrada,
# não há valor para "devolver". É o mesmo raciocínio de toggleable_invulnerabilities: cada
# quem pediu o override é identificado por um token (ex.: a BossAction em execução).

## Faz `profile` valer no lugar da base (os três campos, inclusive os que ele deixa no padrão)
## até pop_override(token). Se houver mais de um, o último a entrar vale. Chamar de novo com o
## mesmo token substitui a entrada dele, sem empilhar. Perfil nulo é ignorado.
func push_override(token: Object, profile: DamageProfile) -> void:
	if token == null or profile == null:
		push_warning("[HitComponent] push_override ignorado: token ou perfil nulo (%s)" % name)
		return
	pop_override(token)
	_overrides.append({"token": token, "profile": profile})


## Remove o override do token. Seguro de chamar qualquer número de vezes, com token que
## nunca entrou ou com a pilha vazia.
func pop_override(token: Object) -> void:
	for i in range(_overrides.size() - 1, -1, -1):
		if _overrides[i]["token"] == token:
			_overrides.remove_at(i)


## Remove todos os overrides (defesa em profundidade: morte, retry).
func clear_overrides() -> void:
	_overrides.clear()


## True se há algum override em vigor.
func has_override() -> bool:
	return _top_override() != null


## O perfil em vigor (o mais recente) ou null. Entradas cujo token já foi liberado da memória
## são descartadas aqui, então um override nunca fica preso por causa de um token que sumiu.
func _top_override() -> DamageProfile:
	for i in range(_overrides.size() - 1, -1, -1):
		var e: Dictionary = _overrides[i]
		if is_instance_valid(e["token"]):
			return e["profile"]
		_overrides.remove_at(i)
	return null


# ─────────────────────────────────────────────────────────────
# INTERNO
# ─────────────────────────────────────────────────────────────

## Existe uma hitbox VIVA do mesmo dono com prioridade maior que a minha? (ainda não diz se
## ela está sobre o alvo). Duck typing sobre o grupo "hitbox_area" (HitboxArea.ranks_above):
## este sistema não conhece a HitboxArea. Sem hitboxes vivas o grupo está vazio e nada muda.
func _has_higher_priority_hitbox() -> bool:
	if not is_inside_tree():
		return false
	var hitboxes: Array[Node] = get_tree().get_nodes_in_group("hitbox_area")
	if hitboxes.is_empty():
		return false
	var me: Node = get_owner_actor()
	for h in hitboxes:
		if h.has_method("ranks_above") and h.ranks_above(me, priority):
			return true
	return false


## Cede a vez se uma hitbox do MESMO dono, de prioridade MAIOR, já está sobre o alvo
## (HitboxArea.outranks). Para CONTINUOUS ceder não descarta o alvo: ele continua em _inside
## e é reavaliado no próximo tick.
func _yields_to_higher_priority(target: Node) -> bool:
	if not is_inside_tree() or not is_instance_valid(target):
		return false
	var hitboxes: Array[Node] = get_tree().get_nodes_in_group("hitbox_area")
	if hitboxes.is_empty():
		return false
	var me: Node = get_owner_actor()
	for h in hitboxes:
		if h.has_method("outranks") and h.outranks(me, priority, target):
			return true
	return false


## Fim do passo de física: agora todas as sobreposições estão atualizadas. Reporta, a menos
## que um golpe de maior prioridade esteja sobre o alvo. (O alvo pode já ter levado o hit do
## golpe maior: nesse caso os i-frames dele descartam este.)
func _settle_priority(target: Node) -> void:
	if not is_instance_valid(target):
		return
	if _yields_to_higher_priority(target):
		return
	HitBus.dispatch(self, target)


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
