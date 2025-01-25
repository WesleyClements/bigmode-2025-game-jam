shader_type canvas_item;

uniform float block_height = 20.0;
uniform float light_height = 10.0;

varying vec3 pos;

vec3 vec_to_color(vec3 input) {
	return (input + 1.0) * 0.5;
}

void vertex() {
}

void fragment() {
	
	float height = block_height * (SPECULAR_SHININESS.r * 2.0 - 1.0);
	
	SHADOW_VERTEX.y = VERTEX.y - height * SCREEN_PIXEL_SIZE.y;
	pos = vec3(VERTEX * SCREEN_PIXEL_SIZE, height);
	
	COLOR.r = height;
}

void light() {

}
