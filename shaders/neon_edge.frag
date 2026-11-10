#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform float uThreshold;
uniform sampler2D uTexture;
out vec4 fragColor;
float lum(vec3 c){ return dot(c, vec3(0.299, 0.587, 0.114)); }
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 px = 1.0 / uSize;
  float l = lum(texture(uTexture, uv).rgb);
  float lx = lum(texture(uTexture, clamp(uv + vec2(px.x, 0.0), vec2(0.0), vec2(1.0))).rgb);
  float ly = lum(texture(uTexture, clamp(uv + vec2(0.0, px.y), vec2(0.0), vec2(1.0))).rgb);
  float e = length(vec2(l - lx, l - ly));
  float edge = smoothstep(uThreshold, uThreshold + 0.25, e);
  vec3 neon = vec3(0.1, 0.9, 1.0) * (0.6 + 0.4 * sin(uTime * 3.0));
  neon = mix(neon, vec3(1.0, 0.2, 0.8), 0.5 + 0.5 * sin(uTime * 1.7 + uv.y * 6.0));
  vec4 base = texture(uTexture, uv);
  vec3 outc = mix(base.rgb * 0.85, base.rgb + neon * edge, clamp(uIntensity * edge, 0.0, 1.0));
  fragColor = vec4(outc, base.a);
}
