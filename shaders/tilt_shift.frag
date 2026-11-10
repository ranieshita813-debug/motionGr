#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uAmount;
uniform float uFocus;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float band = abs(uv.y - uFocus);
  float blur = smoothstep(0.05, 0.45, band) * uAmount * 6.0;
  vec2 px = vec2(1.0 / uSize.x, 0.0) * blur;
  vec2 py = vec2(0.0, 1.0 / uSize.y) * blur;
  vec4 c = vec4(0.0);
  c += texture(uTexture, clamp(uv, vec2(0.0), vec2(1.0))) * 0.4;
  c += texture(uTexture, clamp(uv + px, vec2(0.0), vec2(1.0))) * 0.15;
  c += texture(uTexture, clamp(uv - px, vec2(0.0), vec2(1.0))) * 0.15;
  c += texture(uTexture, clamp(uv + py, vec2(0.0), vec2(1.0))) * 0.15;
  c += texture(uTexture, clamp(uv - py, vec2(0.0), vec2(1.0))) * 0.15;
  fragColor = c;
}
