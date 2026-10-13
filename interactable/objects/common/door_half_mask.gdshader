// levels/common/door_half_mask.gdshader
//
// Mascara metade do sprite (esquerda ou direita) tornando o resto
// transparente. Usado pelos dois AnimatedSprite2D da porta (DoorLeft
// e DoorRight) — ambos tocam a MESMA animação, cada um só revela a
// metade que pertence a ele.
//
// IMPORTANTE: cada sprite precisa de uma INSTÂNCIA separada deste
// material (mesmo shader, materiais diferentes) — senão trocar o
// uniform de um afeta os dois.

shader_type canvas_item;

// true = mostra a metade ESQUERDA (UV.x < 0.5)
// false = mostra a metade DIREITA (UV.x >= 0.5)
uniform bool show_left_half = true;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	bool is_left_pixel = UV.x < 0.5;
	bool belongs_to_this_half = (is_left_pixel == show_left_half);

	COLOR = tex_color;
	if (!belongs_to_this_half) {
		COLOR.a = 0.0;
	}
}
