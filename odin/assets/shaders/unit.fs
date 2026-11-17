// Painterly unit shader: watercolour washes instead of flat voxel bands.
//
// The light ramp is split into a few soft washes whose boundaries wobble with
// noise. Colour is composited the way pigment sits on paper (Beer-Lambert),
// shadows shift to a cool pigment and the silhouette pools dark while a warm
// rim keeps the figure readable against the dark forest.
#version 330

in vec3 fragPosition;
in vec3 fragNormal;
in vec4 fragAlbedo;
in vec2 fragLook;

uniform vec3 u_camera;
uniform vec3 u_key_dir;
uniform float u_time;

out vec4 finalColor;

float hash12(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main()
{
    vec3 N = normalize(fragNormal);
    vec3 V = normalize(u_camera - fragPosition);
    if (dot(N, V) < 0.0)
    {
        N = -N;
    }

    float ao = clamp(fragAlbedo.a, 0.0, 1.0);
    float metal = clamp(fragLook.x, 0.0, 1.0);
    float glow = clamp(fragLook.y, 0.0, 1.0);
    vec3 albedo = fragAlbedo.rgb;

    // Warm key from the upper left, cool sky fill from behind the camera.
    vec3 L = normalize(u_key_dir);
    vec3 F = normalize(vec3(-0.60, 0.35, 0.72));
    float ndl = dot(N, L);
    float key = smoothstep(-0.12, 0.80, ndl);
    float fill = clamp(dot(N, F) * 0.5 + 0.5, 0.0, 1.0) * 0.30;
    float sky = 0.170 + 0.070 * clamp(N.y, 0.0, 1.0);
    float light = key * 0.94 + fill * 0.55 + sky;

    // Soft washes: the terminator wobbles so it never reads as a hard band.
    float wash = value_noise(fragPosition.xz * 7.0 + fragPosition.y * 4.0) - 0.5;
    float bands = 6.0;
    float f = clamp(light * 0.92 + wash * 0.16, 0.0, 1.0) * bands;
    float fr = fract(f);
    float tone = (floor(f) + smoothstep(0.24, 0.76, fr)) / bands;
    float wet = exp(-pow((fr - 0.5) / 0.17, 2.0)) * step(0.02, f) * step(f, bands - 0.02);

    // Pigment over paper. Shadows carry a cool, heavier pigment.
    vec3 shadow_pigment = vec3(0.46, 0.55, 0.76);
    vec3 pigment = mix(albedo, albedo * shadow_pigment * 1.85, (1.0 - tone) * 0.78);
    float density = mix(1.42, 0.82, tone);
    density += wet * 0.14;
    density += (1.0 - ao) * 0.55;
    vec3 paper = vec3(0.93, 0.90, 0.82);
    vec3 col = paper * pow(max(pigment, vec3(0.015)), vec3(density));
    col *= mix(0.24, 1.05, tone);
    col *= 0.92 + 0.14 * ao;

    // Metal glint: tight, few pixels, the way pre-rendered sprites sparkle.
    vec3 H = normalize(L + V);
    float spec = pow(max(dot(N, H), 0.0), mix(20.0, 96.0, metal));
    col += vec3(1.0, 0.96, 0.86) * spec * (0.02 + 0.22 * metal) * (0.30 + 0.70 * key) * ao;

    // Silhouette pools pigment; a warm rim separates figure from background.
    float edge = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 2.7);
    vec3 rim_warm = vec3(1.00, 0.79, 0.50);
    vec3 rim_cool = vec3(0.42, 0.60, 0.90);
    vec3 rim = mix(rim_cool, rim_warm, smoothstep(-0.15, 0.85, ndl));
    col += rim * edge * (0.14 + 0.20 * ao);
    col *= 1.0 - edge * 0.18;

    // Arcane glow from visor, conduits and blade runes.
    float pulse = 0.84 + 0.16 * sin(u_time * 2.4 + fragPosition.y * 5.0);
    col += albedo * glow * (1.35 * pulse + 0.65);

    // A touch of extra chroma keeps the palette upbeat rather than muddy.
    float grey = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(grey), col, 1.14);

    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
