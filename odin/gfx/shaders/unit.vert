#version 450
layout(location=0) in vec3 a_pos;
layout(location=1) in vec2 a_uv;
layout(location=2) in vec3 a_nrm;
layout(location=3) in vec4 a_col;
layout(std140, set=1, binding=0) uniform U { mat4 mvp; mat4 matModel; vec4 colDiffuse; vec4 fb; vec4 u_camera; vec4 u_key_dir; vec4 u_time; vec4 u_tint; vec4 u_fog_vis; };
layout(location=0) out vec3 v_world;
layout(location=1) out vec3 v_normal;
layout(location=2) out vec4 v_albedo;
layout(location=3) out vec2 v_look;
void main() {
	vec4 world = matModel * vec4(a_pos, 1.0);
	v_world = world.xyz;
	v_normal = transpose(inverse(mat3(matModel))) * a_nrm;
	v_albedo = a_col;
	v_look = a_uv;
	gl_Position = mvp * vec4(a_pos, 1.0);
}
