// Unit model vertex shader: passes world-space data for painterly lighting.
// Positions are already world-space for units (CPU skinned, identity model),
// while props such as trees use matModel.
#version 330

in vec3 vertexPosition;
in vec3 vertexNormal;
in vec4 vertexColor;
in vec2 vertexTexCoord;

uniform mat4 mvp;
uniform mat4 matModel;

out vec3 fragPosition;
out vec3 fragNormal;
out vec4 fragAlbedo;
out vec2 fragLook;

void main()
{
    vec4 world = matModel * vec4(vertexPosition, 1.0);
    fragPosition = world.xyz;
    fragNormal = mat3(matModel) * vertexNormal;
    fragAlbedo = vertexColor;
    fragLook = vertexTexCoord;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
