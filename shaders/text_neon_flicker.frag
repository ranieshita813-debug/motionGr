#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform sampler2D uTexture;
out vec4 fragColor;
float hash(float n){ return fract(sin(n) * 43758.5453); }
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 s = texture(uTexture, uv);
  float flick = 0.7 + 0.3 * step(0.2, hash(floor(uTime * 18.0)));
  float pulse = 0.85 + 0.15 * sin(uTime * 10.0);
  vec3 neon = vec3(0.2, 0.9, 1.0);
  vec3 glow = neon * (0.6 + 0.4 * pulse) * flick * uIntensity;
  vec3 outc = mix(s.rgb, s.rgb + glow, 0.7);
  fragColor = vec4(outc, s.a);
}
