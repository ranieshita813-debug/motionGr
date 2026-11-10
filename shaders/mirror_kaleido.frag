#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uSegments;
uniform float uSpeed;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 p = uv - 0.5;
  float a = atan(p.y, p.x) + uTime * 0.2 * uSpeed;
  float r = length(p);
  float seg = max(2.0, floor(uSegments));
  float tau = 6.28318530718;
  a = mod(a, tau / seg);
  a = abs(a - tau / (seg * 2.0));
  vec2 m = vec2(cos(a), sin(a)) * r + 0.5;
  m.x = abs(m.x - 0.5) + 0.5;
  fragColor = texture(uTexture, clamp(m, vec2(0.0), vec2(1.0)));
}
