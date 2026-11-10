#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 s = texture(uTexture, uv);
  float l = dot(s.rgb, vec3(0.299, 0.587, 0.114));
  float scale = mix(4.0, 14.0, clamp(uIntensity / 2.0, 0.0, 1.0));
  vec2 grid = fract(uv * uSize / scale) - 0.5;
  float d = length(grid);
  float r = (1.0 - l) * 0.55;
  float dotMask = smoothstep(r, r - 0.08, d);
  vec3 paper = vec3(0.98, 0.96, 0.9);
  vec3 ink = mix(s.rgb, s.rgb * 0.35, 0.6);
  vec3 col = mix(paper, ink, dotMask);
  fragColor = vec4(mix(s.rgb, col, 0.85), s.a);
}
