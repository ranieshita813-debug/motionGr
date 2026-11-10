#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uAmount;
uniform float uAngle;
uniform sampler2D uTexture;
out vec4 fragColor;
vec4 tex(vec2 p){ return texture(uTexture, clamp(p, vec2(0.0), vec2(1.0))); }
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 dir = vec2(cos(uAngle), sin(uAngle)) * (uAmount * 0.02);
  float pulse = 0.7 + 0.3 * sin(uTime * 2.0);
  dir *= pulse;
  float r = tex(uv + dir).r;
  vec4 g = tex(uv);
  float b = tex(uv - dir).b;
  fragColor = vec4(r, g.g, b, g.a);
}
