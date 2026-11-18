// Ground plane vertex shader: passes UVs and world-space coordinates for
// organic FBM fog-of-war mist transitions and sanctuary border shimmer.
#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;

uniform mat4 mvp;
uniform mat4 matModel;

out vec2 fragTexCoord;
out vec3 fragWorldPos;

void main()
{
    fragTexCoord = vertexTexCoord;
    fragWorldPos = (matModel * vec4(vertexPosition, 1.0)).xyz;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
