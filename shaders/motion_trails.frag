#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uAmount;
uniform float uSpeed;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec3 acc = texture(uTexture, uv).rgb * 0.5;
  for (int i = 1; i <= 5; i++) {
    float fi = float(i);
    vec2 o = vec2(0.01 * fi * uAmount * sin(uTime * uSpeed * 0.3), 0.008 * fi * uAmount);
    float w = 0.5 / (fi + 1.0);
    acc += texture(uTexture, clamp(uv - o, vec2(0.0), vec2(1.0))).rgb * w;
  }
  float norm = 0.5;
  for (int i = 1; i <= 5; i++) norm += 0.5 / float(i + 1);
  fragColor = vec4(acc / norm, texture(uTexture, uv).a);
}
