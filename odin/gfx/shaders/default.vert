// Default program vertex stage (Vulkan). Also used by the watercolour post pass.
#version 450
layout(location=0) in vec3 a_pos;
layout(location=1) in vec2 a_uv;
layout(location=3) in vec4 a_col;
layout(std140, set=1, binding=0) uniform U { mat4 mvp; mat4 matModel; vec4 colDiffuse; vec4 fb; };
layout(location=0) out vec2 v_uv;
layout(location=1) out vec4 v_col;
void main() {
	v_uv = a_uv;
	v_col = a_col;
	gl_Position = mvp * vec4(a_pos, 1.0);
}
