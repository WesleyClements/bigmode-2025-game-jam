shader_type canvas_item;

uniform vec4 depth_color : source_color = vec4(0.0, 0.01953125, 0.0390625, 1.0);
uniform float depth_offset = 0.4;

varying vec3 pos;

void fragment() {
	
	float height = max(SPECULAR_SHININESS.r * 2.0 - 1.0, 0.0);
	float depth = sqrt(height);
	float t = (1.0 - depth_offset) * (1.0  - depth);
	COLOR.r += (depth_color.r-COLOR.r) *t * depth_color.a;
	COLOR.g += (depth_color.g-COLOR.g) *t * depth_color.a;
	COLOR.b += (depth_color.b-COLOR.b) *t * depth_color.a;
	
}

void light() {

}
