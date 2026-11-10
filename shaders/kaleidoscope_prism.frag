#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 c = uv - 0.5;
  float r = length(c);
  float a = atan(c.y, c.x);
  float seg = max(2.0, floor(6.0 * uIntensity));
  float tau = 6.28318530718;
  a = mod(a, tau / seg);
  a = abs(a - (tau / (seg * 2.0)));
  a += uTime * 0.08;
  vec2 p = vec2(cos(a), sin(a)) * r + 0.5;
  vec4 col = texture(uTexture, clamp(p, vec2(0.0), vec2(1.0)));
  vec3 tint = vec3(0.5 + 0.5 * sin(uTime + r * 8.0), 0.5 + 0.5 * sin(uTime * 1.3 + 2.0), 0.5 + 0.5 * sin(uTime * 0.7 + 4.0));
  fragColor = vec4(mix(col.rgb, col.rgb * tint, 0.18 * uIntensity), col.a);
}
