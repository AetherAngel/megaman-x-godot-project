# systems/bt/actions/AnimPhase.gd
class_name AnimPhase
extends Resource

## Uma fase de animação dentro de uma BossAction.
## BossAction tem um Array[AnimPhase] executado em sequência.
##
## Exemplo — Hadouken do Magma Dragoon:
##   Phase 0: anim="hadouken_prep",   exit=ON_FINISH        ← preparação
##   Phase 1: anim="hadouken_fire",   exit=ON_FINISH        ← disparo
##   Phase 2: anim="hadouken_idle",   exit=ON_FINISH        ← recuperação
##
## Exemplo — Rajada de chamas (com loop):
##   Phase 0: anim="charge_start",    exit=ON_FINISH        ← entrada
##   Phase 1: anim="charge_loop",     exit=ON_TIMER  t=2.0  ← loop por 2 segundos
##   Phase 2: anim="charge_end",      exit=ON_FINISH        ← saída

enum ExitOn {
	ON_FINISH,  ## avança quando a animação termina (animação sem loop)
	ON_TIMER,   ## avança após exit_timer segundos (útil para loops cronometrados)
	ON_SIGNAL,  ## avança quando BossAction.advance_phase() for chamado manualmente
				## use para: aguardar FX externo, aguardar condição complexa do boss
	ON_MOVE_END,  ## avança quando o physical_move desta fase termina (ex: pulo até pousar)
}

@export_group("Animation")
## Nome da animação no SpriteFrames do boss. Deve existir no .tres carregado.
@export var anim_name: StringName = &"idle"

@export_group("Exit Condition")
@export var exit: ExitOn = ExitOn.ON_FINISH
## Duração em segundos. Usado apenas se exit = ON_TIMER.
@export var exit_timer: float = 1.0
## Timeout de segurança para ON_SIGNAL.
## Se o signal não chegar em signal_timeout segundos, avança forçado.
## Evita que o boss trave para sempre por um bug de sincronização.
@export var signal_timeout: float = 5.0

@export_group("Movement")
## Movimento físico executado ao entrar nesta fase (reaproveita Actor.start_physical_move:
## mesma gravidade, colisões e condições de saída TIMER / APEX / LANDING). Use
## exit = ON_MOVE_END para a fase durar até o movimento terminar. A animação vem DESTE
## AnimPhase — o campo `animation` das fases do movimento não é usado no combate.
## O movimento só começa/termina aqui; quem decide o próximo ataque continua sendo a BT.
@export var physical_move: PhysicalMoveDef

@export_group("Landing")
## Se true, ao TERMINAR esta fase o boss verifica se pousou em chão seguro
## (Boss.is_landing_safe). Se não, executa as recovery_phases da BossAction e só depois
## segue para a próxima fase — o resto do combo só continua depois de voltar à arena.
@export var check_landing: bool = false

@export_group("Invulnerability")
## Se true, o ator fica invulnerável enquanto ESTA fase de animação durar.
## A duração é a da própria fase (ON_FINISH / ON_TIMER / ON_SIGNAL) — não há segundo
## tempo para manter em sincronia. Liberada ao sair da fase, ao fim da ação ou se ela
## for interrompida.
@export var invulnerable: bool = false

@export_group("Frame Events")
## Eventos disparados em frames específicos desta fase.
## Configurados no editor como peças de lego.
@export var frame_events: Array[FrameEvent] = []
