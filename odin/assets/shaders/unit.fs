// Painterly Toriyama / Dragon Quest watercolour shader for units and props.
//
// Uses a crisp 4-tone illustrative ramp (cobalt-violet shadow -> mid shadow ->
// bright midtone -> warm sunlit highlight) with no muddy black crushing, tight
// metallic specular gleam, grazing-only silhouette contour ink wash, and smooth
// fog-of-war shroud blending via u_fog_vis.
#version 330

in vec3 fragPosition;
in vec3 fragNormal;
in vec4 fragAlbedo;
in vec2 fragLook;

uniform vec3 u_camera;
uniform vec3 u_key_dir;
uniform float u_time;
uniform vec3 u_tint;
uniform float u_fog_vis;

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
    vec3 albedo = fragAlbedo.rgb * u_tint;

    vec3 L = normalize(u_key_dir);
    vec3 F = normalize(vec3(-0.62, 0.34, 0.70));
    float ndl = dot(N, L);
    float ndv = clamp(dot(N, V), 0.0, 1.0);

    float key = smoothstep(-0.22, 0.86, ndl);
    float fill = (dot(N, F) * 0.5 + 0.5) * 0.24;
    float sky = 0.12 + 0.10 * clamp(N.y, 0.0, 1.0);
    float wash = (value_noise(fragPosition.xz * 7.5 + fragPosition.y * 4.5) - 0.5) * 0.085;
    float lv = clamp(key * 0.78 + fill + sky * 0.65 + wash - (1.0 - ao) * 0.18, 0.0, 1.0);

    // Crisp 4-tone Toriyama ramp: cobalt/violet shadow through sunlit highlight.
    float t1 = smoothstep(0.20, 0.28, lv);
    float t2 = smoothstep(0.44, 0.52, lv);
    float t3 = smoothstep(0.74, 0.82, lv);

    vec3 c0 = albedo * vec3(0.44, 0.46, 0.68);
    vec3 c1 = albedo * vec3(0.68, 0.70, 0.86);
    vec3 c2 = albedo * vec3(1.00, 0.99, 0.96);
    vec3 c3 = mix(albedo * vec3(1.12, 1.07, 0.93), vec3(1.00, 0.97, 0.88), 0.14);

    vec3 col = mix(c0, c1, t1);
    col = mix(col, c2, t2);
    col = mix(col, c3, t3);

    // Soft pigment pooling at the primary shadow terminator and gentle AO.
    float term_pool = exp(-pow((lv - 0.48) / 0.055, 2.0));
    col *= 1.0 - term_pool * 0.06;
    col *= mix(0.76, 1.03, ao);

    // Tight crisp metallic gleam.
    vec3 H = normalize(L + V);
    float spec_pow = mix(28.0, 120.0, metal);
    float spec_raw = pow(max(dot(N, H), 0.0), spec_pow);
    float spec = mix(spec_raw * 0.25, smoothstep(0.18, 0.55, spec_raw), step(0.25, metal));
    col += vec3(1.00, 0.96, 0.86) * spec * (0.04 + 0.34 * metal) * (0.35 + 0.65 * t2) * ao;

    // Grazing silhouette contour ink wash + rim separation, cleanly skipping front faces.
    float grazing = 1.0 - ndv;
    float silhouette = smoothstep(0.55, 0.96, grazing);
    vec3 rim_warm = vec3(1.00, 0.84, 0.54);
    vec3 rim_cool = vec3(0.48, 0.66, 0.94);
    vec3 rim = mix(rim_cool, rim_warm, smoothstep(-0.10, 0.82, ndl));
    col = mix(col, col * vec3(0.44, 0.42, 0.56), silhouette * 0.40);
    col += rim * smoothstep(0.50, 0.92, grazing) * (0.10 + 0.14 * ao);

    // Arcane glow scaled cleanly by fog visibility.
    float vis = clamp(u_fog_vis, 0.0, 1.0);
    float pulse = 0.86 + 0.14 * sin(u_time * 2.4 + fragPosition.y * 5.0);
    col += albedo * glow * (1.25 * pulse + 0.55) * vis;

    // Preserve lively chroma, then blend explored props into moonlit memory.
    float grey = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(grey), col, 1.10);

    vec3 fog_mem = mix(vec3(grey), col, 0.52) * vec3(0.32, 0.41, 0.53) + vec3(0.014, 0.022, 0.034);
    col = mix(fog_mem, col, smoothstep(0.36, 1.0, vis));

    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
