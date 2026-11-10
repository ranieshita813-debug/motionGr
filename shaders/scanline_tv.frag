#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform sampler2D uTexture;
out vec4 fragColor;
float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 s = texture(uTexture, uv);
  float scan = 0.85 + 0.15 * sin((uv.y * uSize.y * 1.2) - uTime * 10.0 * uSpeed);
  float roll = smoothstep(0.0, 1.0, fract(uv.y - uTime * 0.08 * uSpeed));
  float noise = (hash(uv * uSize + uTime) - 0.5) * 0.08;
  vec3 c = s.rgb * mix(1.0, scan, uIntensity);
  c += noise * uIntensity;
  c += roll * 0.03 * uIntensity;
  fragColor = vec4(clamp(c, 0.0, 1.0), s.a);
}
