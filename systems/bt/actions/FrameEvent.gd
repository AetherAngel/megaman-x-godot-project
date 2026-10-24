# systems/bt/actions/FrameEvent.gd
class_name FrameEvent
extends Resource

## Evento disparado em um frame específico de uma animação.
## Configurado no editor como parte de uma AnimPhase.
##
## Eventos simples (hitbox, FX, SFX) são configurados aqui.
## Lógica complexa específica do boss é implementada em BossAction._on_hitbox_event().
##
## Exemplo:
##   frame = 3, type = HITBOX_ON,  value = &"hitbox_main"     → liga hitbox no frame 3
##   frame = 8, type = HITBOX_OFF, value = &"hitbox_main"     → desliga hitbox no frame 8
##   frame = 5, type = SPAWN_FX,   particle_def = <resource>  → spawna partícula no frame 5
##   frame = 6, type = SPAWN_FX,   fx_resource = <FXChainDef> → spawna uma cadeia segmentada
##   frame = 0, type = PLAY_SFX,   value = &"sfx_swipe"       → toca SFX no frame 0

enum Type {
	HITBOX_ON,     ## liga o hitbox identificado por `value`
	HITBOX_OFF,    ## desliga o hitbox identificado por `value`
	SPAWN_FX,      ## spawna o efeito referenciado em `fx_resource` (preferencial) ou `particle_def` (legado)
	PLAY_SFX,      ## toca SFX identificado por `value`
	SPAWN_OBJECT,  ## spawna um objeto de gameplay (bola de fogo, meteoro) — usa `spawn_object`, não `value`
}

## Frame da animação em que este evento dispara. Base 0.
@export var frame: int = 0
@export var type: Type = Type.HITBOX_ON
## Nome do hitbox a acionar (HITBOX_ON/OFF) ou id do sfx no sounds.json (PLAY_SFX).
@export var value: StringName = &""

## Efeito de partícula a spawnar (SPAWN_FX). Campo LEGADO — só aceita
## SpawnedParticleDef. Prefira `fx_resource` abaixo para qualquer Def novo.
## Se `fx_resource` estiver preenchido, ele tem prioridade sobre este campo.
@export var particle_def: SpawnedParticleDef

## Efeito genérico a spawnar (SPAWN_FX). Aceita qualquer Def do sistema de
## FX que precise passar por um FrameEvent — resolvido por tipo em
## BossAction._dispatch_spawn_fx(). Tipos catalogados hoje:
##   - FXChainDef → cadeia segmentada (ParticleFX.spawn_chain). Segue o
##     último objeto criado por um SPAWN_OBJECT anterior na mesma ação —
##     configure o SPAWN_OBJECT da cabeça ANTES deste evento na sequência.
##   - BarrageDef → saraivada em lanes (BarrageController): roda o preamble, chove com
##     espaçamento controlado e, ao terminar, avança a AnimPhase atual (use exit = ON_SIGNAL).
## Pra suportar um Def novo no futuro: só adicionar um `elif` em
## _dispatch_spawn_fx(), este campo não precisa mudar.
@export var fx_resource: Resource

## Objeto de gameplay a instanciar (com dano, lifetime, hitbox próprios).
## Usado apenas quando type = SPAWN_OBJECT.
@export var spawn_object: SpawnableObject
