#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uBlurAmount;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 r = (uBlurAmount * 6.0) / uSize;
  vec4 c = vec4(0.0);
  c += texture(uTexture, clamp(uv + vec2(-r.x, -r.y), vec2(0.0), vec2(1.0))) * 0.0625;
  c += texture(uTexture, clamp(uv + vec2(0.0, -r.y), vec2(0.0), vec2(1.0))) * 0.125;
  c += texture(uTexture, clamp(uv + vec2(r.x, -r.y), vec2(0.0), vec2(1.0))) * 0.0625;
  c += texture(uTexture, clamp(uv + vec2(-r.x, 0.0), vec2(0.0), vec2(1.0))) * 0.125;
  c += texture(uTexture, uv) * 0.25;
  c += texture(uTexture, clamp(uv + vec2(r.x, 0.0), vec2(0.0), vec2(1.0))) * 0.125;
  c += texture(uTexture, clamp(uv + vec2(-r.x, r.y), vec2(0.0), vec2(1.0))) * 0.0625;
  c += texture(uTexture, clamp(uv + vec2(0.0, r.y), vec2(0.0), vec2(1.0))) * 0.125;
  c += texture(uTexture, clamp(uv + vec2(r.x, r.y), vec2(0.0), vec2(1.0))) * 0.0625;
  fragColor = c;
}
