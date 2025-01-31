shader_type canvas_item;

uniform vec4 depth_color : source_color = vec4(0.0, 0.05078125, 0.099613375, 1.0);
uniform float depth_offset = 0.1;

varying vec3 pos;

void fragment() {
	
	float height = SPECULAR_SHININESS.r * 2.0 - 1.0;
	float depth = 2.0 *(1.0 - 1.0/ (height + 1.0)) * (1.0 - depth_offset) + depth_offset;
	float t = depth;
	float unt = 1.0 - depth;
	COLOR.r = COLOR.r * t + depth_color.r *unt;
	COLOR.g = COLOR.g * t + depth_color.g *unt;
	COLOR.b = COLOR.b * t + depth_color.b *unt;
	
}

void light() {

}
