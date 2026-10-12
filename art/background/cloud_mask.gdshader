shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sky_mask : filter_nearest, repeat_disable;
varying vec2 world_pixel;
void vertex() {
	world_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	COLOR *= texture(sky_mask, world_pixel / vec2(640.0, 318.0)).r;
}
