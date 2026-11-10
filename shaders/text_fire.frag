#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform sampler2D uTexture;
out vec4 fragColor;
float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 s = texture(uTexture, uv);
  float n = hash(uv * vec2(20.0, 8.0) + vec2(0.0, -uTime * 3.0));
  float flame = smoothstep(0.2, 1.0, 1.0 - uv.y + n * 0.3);
  vec3 fire = mix(vec3(0.6, 0.0, 0.0), vec3(1.0, 0.8, 0.1), flame);
  fire = mix(fire, vec3(1.0), pow(flame, 3.0) * 0.5);
  vec3 outc = mix(s.rgb, fire, 0.7 * uIntensity + 0.1);
  fragColor = vec4(outc, s.a);
}
