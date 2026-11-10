#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 base = texture(uTexture, uv);
  vec3 acc = vec3(0.0);
  float wsum = 0.0;
  for (int x = -2; x <= 2; x++) {
    for (int y = -2; y <= 2; y++) {
      vec2 o = vec2(float(x), float(y)) * 2.5 / uSize;
      float w = exp(-0.2 * float(x * x + y * y));
      acc += texture(uTexture, clamp(uv + o, vec2(0.0), vec2(1.0))).rgb * w;
      wsum += w;
    }
  }
  vec3 blur = acc / max(wsum, 0.001);
  vec3 glow = max(blur - 0.35, vec3(0.0)) * uIntensity * 2.2;
  fragColor = vec4(base.rgb + glow, base.a);
}
