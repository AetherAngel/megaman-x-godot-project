# systems/damage/DamageType.gd
class_name DamageType

## Vocabulário central de tipos de dano.
## Nenhum sistema usa strings soltas para tipos de dano — apenas estas constantes.
##
## Como adicionar um novo tipo:
##   1. Adicione a constante aqui
##   2. Configure nas DamageResistanceTable dos bosses relevantes
##   Pronto — zero mudança em qualquer outro sistema.
##
## Uso:
##   DamageType.FIRE      → &"fire"
##   DamageType.ELECTRIC  → &"electric"

## Dano físico genérico — buster padrão, ataques sem elemento
const BUSTER   : StringName = &"buster"
## Colisão corpo a corpo sem elemento — contato com inimigo, projétil sem tipo
const CONTACT  : StringName = &"contact"

## Variantes do Buster — cada tipo de tiro tem sua entrada na DamageResistanceTable
## do boss, como no MMX original (o charged shot não causa o mesmo que o tiro normal).
## BUSTER continua sendo o tiro normal (lv1).
const BUSTER_CHARGE_LV2 : StringName = &"buster_charge_lv2"
const BUSTER_CHARGE_LV3 : StringName = &"buster_charge_lv3"
const BUSTER_PLASMA     : StringName = &"buster_plasma"

## Ataques de sabre — separados do Buster.
const SABER    : StringName = &"saber"

## Tipos elementais — usados por técnicas do Zero e Special Weapons do X
const FIRE     : StringName = &"fire"
const ICE      : StringName = &"ice"
const ELECTRIC : StringName = &"electric"
const WIND     : StringName = &"wind"
const WATER    : StringName = &"water"
const EARTH    : StringName = &"earth"
const LIGHT    : StringName = &"light"
