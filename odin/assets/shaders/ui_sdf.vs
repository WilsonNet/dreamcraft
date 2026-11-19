// Batched UI SDF card/pill vertex shader: packs per-widget data slot in vertexPosition.z
// and local pixel coordinates in vertexTexCoord for single-draw-call UI chrome.
#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;

uniform mat4 mvp;

flat out int v_slot;
out vec2 v_local;
out vec4 v_color;

void main()
{
    v_slot = int(vertexPosition.z + 0.5);
    v_local = vertexTexCoord;
    v_color = vertexColor;
    gl_Position = mvp * vec4(vertexPosition.xy, 0.0, 1.0);
}
