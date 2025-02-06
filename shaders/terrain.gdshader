shader_type canvas_item;

uniform float height_scale = 32.0;
uniform vec4 depth_color : source_color = vec4(0.0, 0.01953125, 0.0390625, 1.0);
uniform float depth_offset = 0.0;


void fragment() {
	vec4 specular = texture(SPECULAR_SHININESS_TEXTURE, UV);
	if (specular.a > 0.0) {
			float depth = sqrt(specular.r);
			float t = (1.0 - depth_offset) * (1.0  - depth);
			COLOR.r += (depth_color.r-COLOR.r) *t * depth_color.a;
			COLOR.g += (depth_color.g-COLOR.g) *t * depth_color.a;
			COLOR.b += (depth_color.b-COLOR.b) *t * depth_color.a;
	}
	
}