# systems/damage/DamageTypeResolver.gd
class_name DamageTypeResolver

## Resolve o dano final consultando a DamageResistanceTable do alvo.
##
## É uma classe estática pura: sem estado, sem Node, sem Resource.
## Entrada: raw units + tipo + tabela → Saída: unidades finais.
##
## Regras:
##   - Tipo encontrado na tabela → usa o valor da tabela (ignora raw)
##   - Tipo ausente na tabela   → usa table.default_damage
##   - Tabela null              → retorna raw (sem modificação)
##   - Resultado 0              → imune (DamageHandler descarta)


## Resolve o dano final de acordo com a tabela de resistência do alvo.
## raw:     dano em unidades antes da resolução
## type_id: StringName do tipo de dano (use DamageType.FIRE, etc.)
## table:   DamageResistanceTable do boss/inimigo. Null = sem resolução.
static func resolve(raw: int, type_id: StringName, table: DamageResistanceTable) -> int:
	if table == null:
		return raw

	if table.entries.has(type_id):
		return int(table.entries[type_id])

	return table.default_damage
