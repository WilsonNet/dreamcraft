#version 450
layout(location=0) in vec2 v_uv;
layout(location=1) in vec4 v_col;
layout(set=2, binding=0) uniform sampler2D texture0;
layout(std140, set=3, binding=0) uniform U { mat4 mvp; mat4 matModel; vec4 colDiffuse; vec4 fb; };
layout(location=0) out vec4 o_color;
void main() {
	o_color = texture(texture0, v_uv) * colDiffuse * v_col;
}
