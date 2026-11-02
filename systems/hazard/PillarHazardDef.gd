# systems/hazard/PillarHazardDef.gd
class_name PillarHazardDef
extends Resource

## Configuração de UM pilar (PillarHazard): aparência, dimensões, velocidades e dano.
## É só dado — o comportamento mora em PillarHazard.gd. O mesmo script atende lava,
## gelo, espinhos... trocando apenas este Resource.
##
## CONVENÇÃO DE MEDIDAS (uma só, para tudo):
##   Todo comprimento deste Resource está em PIXELS ORIGINAIS (o tamanho da arte).
##   `pillar_scale` é aplicado UMA vez, no final, para chegar ao tamanho real no mundo.
##   Consequência: mudar `pillar_scale` não muda a duração do ciclo — a coluna só
##   fica proporcionalmente maior/menor (altura e velocidade escalam juntas).
##   O que foge à regra: `z_index`, `hitbox_mask` e os tempos (segundos).

enum GrowthDirection {
	UP,    ## sobe (eixo Y negativo) — pilar de chão
	DOWN,  ## desce (eixo Y positivo) — pilar de teto
}

## Tolerância para o floor() da contagem de segmentos não perder um módulo por
## erro de ponto flutuante (ex: 71.99999 / 24).
const _EPS := 0.0001

@export_group("Visuals")
## SpriteFrames da ponta (Top). Ex: 64x24, 3 frames.
@export var top_frames: SpriteFrames
@export var top_animation: StringName = &"default"
## SpriteFrames do corpo (Body). Ex: 48x24, 3 frames. Só é obrigatório se max_body_segments > 0.
@export var body_frames: SpriteFrames
@export var body_animation: StringName = &"default"
## Se true, a arte é espelhada verticalmente quando o pilar cresce para baixo (teto).
@export var flip_art_when_down: bool = true
@export var z_index: int = 20

@export_group("Structure")
## Capacidade: quantos segmentos Body são CRIADOS para a instância.
@export_range(0, 32) var max_body_segments: int = 4
## Altura máxima DESEJADA (px originais). A altura efetiva é o maior valor
## estruturalmente possível (Top + n·Body) que não passe disso nem da capacidade.
@export var max_height: float = 120.0
## Escala dimensional de TODA a cena do pilar (sprites, máscara, hitbox, altura).
## Aceita X e Y diferentes. Use ISTO em vez de escalar o nó (ver PillarHazard).
@export var pillar_scale: Vector2 = Vector2.ONE
@export var growth_direction: GrowthDirection = GrowthDirection.UP

@export_group("Motion")
## Velocidade de subida e de descida (px originais por segundo). Constantes e independentes.
@export var rise_speed: float = 120.0
@export var fall_speed: float = 120.0
## Tempo (s) parado na altura máxima efetiva.
@export var hold_time: float = 1.0
## Quantos px do Top ficam visíveis fora do chão antes de subir (espera inicial e rest_time).
## É SÓ VISUAL: não entra na altura efetiva e a hitbox continua desligada.
@export var peek_height: float = 4.0

@export_group("Hitbox")
## Largura da hitbox (px originais). A largura real é hitbox_width * pillar_scale.x.
@export var hitbox_width: float = 48.0
## Quem a hitbox enxerga. Padrão 36 = layers "player" e "playeronly" (igual à lava).
@export_flags_2d_physics var hitbox_mask: int = 36

@export_group("Damage")
## Repassados ao HitComponent. Quando o boss spawna o pilar (SPAWN_OBJECT), os valores
## do SpawnableObject sobrescrevem estes.
@export var damage: float = 4.0
@export var damage_type_id: StringName = DamageType.FIRE
@export var damage_tag: String = "fire"


# ── Medidas derivadas (px originais, lidas dos sprites reais — sem número mágico) ──

## Nome de animação utilizável: o pedido, se existir; senão a primeira do SpriteFrames.
## Devolve &"" se o SpriteFrames for nulo ou não tiver nenhuma animação.
static func resolve_animation(frames: SpriteFrames, wanted: StringName) -> StringName:
	if frames == null:
		return &""
	if frames.has_animation(wanted):
		return wanted
	var names := frames.get_animation_names()
	return StringName(names[0]) if names.size() > 0 else &""


## Tamanho do primeiro frame da animação. Vector2.ZERO se o SpriteFrames/animação não existir.
static func frame_size(frames: SpriteFrames, anim: StringName) -> Vector2:
	var name := resolve_animation(frames, anim)
	if name == &"" or frames.get_frame_count(name) == 0:
		return Vector2.ZERO
	var tex := frames.get_frame_texture(name, 0)
	return tex.get_size() if tex else Vector2.ZERO


func get_top_size() -> Vector2:
	return frame_size(top_frames, top_animation)


func get_body_size() -> Vector2:
	return frame_size(body_frames, body_animation)


## Escala segura: sempre positiva e nunca zero (escala 0 zeraria a hitbox e dividiria por zero).
func get_safe_scale() -> Vector2:
	return Vector2(maxf(absf(pillar_scale.x), _EPS), maxf(absf(pillar_scale.y), _EPS))


## Quantos Body cabem de fato: min(capacidade, quanto max_height comporta depois do Top).
func get_effective_body_count() -> int:
	var body_h := get_body_size().y
	if max_body_segments <= 0 or body_h <= 0.0:
		return 0
	var room := max_height - get_top_size().y
	if room <= 0.0:
		return 0
	return mini(max_body_segments, int(floorf(room / body_h + _EPS)))


## Altura efetiva máxima em px ORIGINAIS: Top + n·Body. No mínimo a altura do Top
## (é o menor pilar estruturalmente possível, mesmo com max_height menor que isso).
func get_effective_height() -> float:
	return get_top_size().y + get_effective_body_count() * get_body_size().y


## Altura efetiva máxima já com pillar_scale.y — o que o pilar ocupa no mundo.
func get_effective_height_world() -> float:
	return get_effective_height() * get_safe_scale().y


## Área que o pilar ocupa no mundo, com escala: largura da arte mais larga × altura efetiva.
## É o que quem decide ONDE colocar o pilar precisa validar (não só um ponto central).
func get_footprint_size() -> Vector2:
	var width := get_top_size().x
	if get_effective_body_count() > 0:
		width = maxf(width, get_body_size().x)
	var s := get_safe_scale()
	return Vector2(width * s.x, get_effective_height() * s.y)


## true se dá para montar o pilar: existe Top, e existe Body quando há segmentos.
func is_buildable() -> bool:
	if get_top_size().y <= 0.0:
		return false
	if max_body_segments > 0 and get_body_size().y <= 0.0:
		return false
	return true
