# HitBus.gd
# Autoload — adicione em Project > Autoloads com o nome "HitBus"
extends Node

## Ponto central de comunicação entre "um hit aconteceu" e o sistema de HP.
##
## O HitBus NÃO calcula dano, NÃO aplica resistência e NÃO mexe em HP.
## Ele apenas valida o evento e o encaminha ao take_damage() do alvo.
## Tudo que vem depois (tabela de resistência, armadura, i-frames, sinais)
## continua sendo responsabilidade do DamageHandler / HPSystem existentes.
##
## Fluxo:
##   HitComponent.report(target) → HitBus.dispatch(hit, target)
##       → target.take_damage(hit.damage, hit)


## Recebe um hit e o encaminha ao alvo.
##
## hit   : HitComponent que originou o evento (attacker, source, damage, tipo).
## target: nó atingido. Normalmente o corpo (CharacterBody2D) do Player/Boss.
##
## O próprio hit é passado como `inflicter`: ele implementa
## get_damage_type_id() e get_damage_tag(), que Player e Boss já leem.
func dispatch(hit: HitComponent, target: Node) -> void:
	if not is_instance_valid(hit) or not is_instance_valid(target):
		return

	# Ninguém se machuca com o próprio ataque.
	if target == hit.get_attacker():
		return

	# Cenário, paredes e qualquer coisa sem HP são descartados silenciosamente.
	if not target.has_method("take_damage"):
		return

	target.take_damage(hit.damage, hit)
