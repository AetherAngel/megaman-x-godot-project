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

## Quem causou o hit. Atribuído por quem spawna o objeto (ex: ChargeSystem, Boss).
## Se ninguém atribuir, get_attacker() devolve o próprio source.
var attacker: Node = null

## O objeto que originou o hit (o pai deste componente).
var source: Node = null


func _ready() -> void:
	source = get_parent()

	if not auto_report:
		return

	var area := source as Area2D
	if area:
		area.body_entered.connect(_on_auto_body_entered)
	else:
		push_warning("[HitComponent] auto_report exige que o pai seja uma Area2D: '%s'" % source.name)


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
	report(body)
