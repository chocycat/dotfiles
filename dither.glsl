#version 330

in vec2 texcoord;
uniform sampler2D tex;

vec4 default_post_processing(vec4 c);

const float SCALE = 1;
const float BLACK_POINT = 0.25;
const float WHITE_POINT = 0.75;

const float bayer4x4[16] = float[](
     0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
    12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
     3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
    15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
);

float getBayer4x4(vec2 pos) {
    ivec2 p = ivec2(mod(pos, 4.0));
    return bayer4x4[p.y * 4 + p.x];
}

vec4 window_shader() {
    vec2 texsize = textureSize(tex, 0);
    vec4 color = texture2D(tex, texcoord / texsize, 0);

    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));

    float dithered;

    if (gray <= BLACK_POINT) {
        dithered = 0.0;
    } else if (gray >= WHITE_POINT) {
        dithered = 1.0;
    } else {
        float remapped = (gray - BLACK_POINT) / (WHITE_POINT - BLACK_POINT);
        vec2 scaled_pos = floor(gl_FragCoord.xy / SCALE);
        float threshold = getBayer4x4(scaled_pos);
        dithered = step(threshold, remapped);
    }

    vec4 result = vec4(vec3(dithered), color.a);
    return default_post_processing(result);
}
