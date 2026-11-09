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
##   frame = 5, type = SPAWN_FX,   particle_def = <SpawnedParticleDef> → spawna partículas comuns no frame 5
##   frame = 6, type = SPAWN_FX,   fx_resource = <FXChainDef>          → spawna uma cadeia segmentada (Def com lógica própria)
##   frame = 0, type = PLAY_SFX,   value = &"sfx_swipe"       → toca SFX no frame 0

enum Type {
	HITBOX_ON,     ## liga o hitbox identificado por `value`
	HITBOX_OFF,    ## desliga o hitbox identificado por `value`
	SPAWN_FX,      ## spawna `particle_def` (SpawnedParticleDef) ou `fx_resource` (Defs com lógica própria: FXChainDef, BarrageDef)
	PLAY_SFX,      ## toca SFX identificado por `value`
	SPAWN_OBJECT,  ## spawna um objeto de gameplay (bola de fogo, meteoro) — usa `spawn_object`, não `value`
	RELEASE_OBJECT,  ## solta o ÚLTIMO objeto criado por um SPAWN_OBJECT desta ação: chama release() nele
}

## Frame da animação em que este evento dispara. Base 0.
@export var frame: int = 0
@export var type: Type = Type.HITBOX_ON
## Nome do hitbox a acionar (HITBOX_ON/OFF) ou id do sfx no sounds.json (PLAY_SFX).
@export var value: StringName = &""

## Partícula comum a spawnar (SPAWN_FX). Aceita APENAS SpawnedParticleDef: rajadas, fumaça,
## faíscas, overlays e FX que acompanham o dono (marker_path, offset, follow_marker e
## inherit_facing são resolvidos em relação ao Boss). O nome do campo é histórico: ele NÃO é
## obsoleto. Se `fx_resource` estiver preenchido, ele tem prioridade e este campo é ignorado.
@export var particle_def: SpawnedParticleDef

## Defs com lógica PRÓPRIA (que gerenciam a si mesmos), spawnados por SPAWN_FX — resolvido por
## tipo em BossAction._dispatch_spawn_fx(). NÃO suporta SpawnedParticleDef: ele vai no campo
## `particle_def`; colocá-lo aqui gera o aviso "fx_resource com tipo não suportado" e nada
## nasce. Tipos suportados hoje:
##   - FXChainDef → cadeia segmentada (ParticleFX.spawn_chain). Segue o
##     último objeto criado por um SPAWN_OBJECT anterior na mesma ação —
##     configure o SPAWN_OBJECT da cabeça ANTES deste evento na sequência.
##   - BarrageDef → saraivada em lanes (BarrageController): roda o preamble, chove com
##     espaçamento controlado e, ao terminar, avança a AnimPhase atual (use exit = ON_SIGNAL).
## Pra suportar um Def novo com lógica própria: só adicionar um `elif` em
## _dispatch_spawn_fx(), este campo não precisa mudar.
@export var fx_resource: Resource

## Objeto de gameplay a instanciar (com dano, lifetime, hitbox próprios).
## Usado apenas quando type = SPAWN_OBJECT.
@export var spawn_object: SpawnableObject
