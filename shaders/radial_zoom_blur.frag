#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uBlurAmount;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 center = vec2(0.5);
  vec2 dir = uv - center;
  vec3 acc = vec3(0.0);
  float samples = 12.0;
  for (float i = 0.0; i < 12.0; i++) {
    float t = i / samples;
    vec2 p = uv - dir * t * uBlurAmount * 0.12;
    acc += texture(uTexture, clamp(p, vec2(0.0), vec2(1.0))).rgb;
  }
  vec4 base = texture(uTexture, uv);
  fragColor = vec4(acc / samples, base.a);
}
