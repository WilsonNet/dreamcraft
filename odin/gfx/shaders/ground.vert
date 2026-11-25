#version 450
layout(location=0) in vec3 a_pos;
layout(location=1) in vec2 a_uv;
layout(std140, set=1, binding=0) uniform U { mat4 mvp; mat4 matModel; vec4 colDiffuse; vec4 fb; vec4 s_time; };
layout(location=0) out vec2 v_uv;
layout(location=1) out vec3 v_world;
void main() {
	v_uv = a_uv;
	v_world = (matModel * vec4(a_pos, 1.0)).xyz;
	gl_Position = mvp * vec4(a_pos, 1.0);
}
