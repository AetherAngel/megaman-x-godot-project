# ui/hud/hp_bar/HPBarConfig.gd
class_name HPBarConfig
extends Resource

## Configuração visual e de posição de uma instância de HPBar.
## Crie um .tres para a barra do player e outro para a barra do boss.
##
## screen_position define ONDE a barra aparece na tela (320×216).
## A origem do HPBar é o ponto do ICON. A barra cresce a partir dali.
##
## Referência para 320×216:
##   Vertical  — Player (esquerda): screen_position = Vector2(8, 192)
##   Vertical  — Boss   (direita):  screen_position = Vector2(298, 192)
##   Horizontal — Player (topo):    screen_position = Vector2(8, 8)
##   Horizontal — Boss   (base):    screen_position = Vector2(8, 200)

enum Orientation {
	VERTICAL,   ## Estilo MMX1–6: lateral, cresce de baixo para cima
	HORIZONTAL, ## Estilo MMX8: topo/base, cresce da esquerda para direita
}

@export_group("Layout")
@export var orientation: int = Orientation.VERTICAL  # enums são ints por baixo dos panos

@export_group("Screen Position")
## Posição do nó HPBar dentro do HUD (CanvasLayer).
## É a posição do ICON na tela — a barra cresce a partir daqui.
@export var screen_position: Vector2 = Vector2(8, 192)

@export_group("Icon")
## Offset do sprite de ícone relativo à origem do HPBar.
## Vertical: ícone fica abaixo das units → Vector2(0, 8).
@export var icon_offset: Vector2 = Vector2(0, 8)

## Override manual do ícone.
## Player: deixe VAZIO — a barra lê o ícone de CharacterManagement automaticamente.
## Boss: preencha com o nome da animação do ícone, ex: &"repliboss_icon".
## O nome precisa existir dentro do spr_bar1_icon.tres.
@export var icon_override: StringName = &""

@export_group("Limit")
## Offset do sprite de limite relativo ao topo da barra.
@export var limit_offset: Vector2 = Vector2(0, -4)

@export_group("Boss Fill")
## Velocidade do fill visual durante BOSS_PRESENTATION (units/segundo).
## MMX original: ~16 units/segundo.
@export var boss_fill_speed: float = 16.0
