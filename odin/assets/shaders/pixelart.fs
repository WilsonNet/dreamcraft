#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec2 texSize;

out vec4 finalColor;

float bayer4(vec2 p) {
    int x = int(mod(p.x, 4.0));
    int y = int(mod(p.y, 4.0));
    int index = x + y * 4;
    float table[16] = float[16](
        0.0,  8.0,  2.0, 10.0,
       12.0,  4.0, 14.0,  6.0,
        3.0, 11.0,  1.0,  9.0,
       15.0,  7.0, 13.0,  5.0
    );
    return table[index] / 16.0 - 0.46875;
}

void main() {
    vec2 texel = floor(fragTexCoord * texSize);
    vec2 uv = (texel + 0.5) / texSize;
    vec3 color = texture(texture0, uv).rgb;

    // Pixel-art outline from neighbouring low-res texels.
    vec2 px = 1.0 / texSize;
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    float lx = dot(texture(texture0, uv + vec2(px.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
    float ly = dot(texture(texture0, uv + vec2(0.0, px.y)).rgb, vec3(0.299, 0.587, 0.114));
    if (abs(luma - lx) > 0.24 || abs(luma - ly) > 0.24) {
        color *= 0.78;
    }

    // Light posterization/dithering; skip near-black fog so it stays clean.
    if (luma > 0.10) {
        float levels = 12.0;
        float d = bayer4(texel) * 0.35;
        color = floor(color * levels + d + 0.5) / levels;
    }
    color = clamp(color, 0.0, 1.0);
    finalColor = vec4(color, 1.0) * colDiffuse * fragColor;
}
