#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 s = texture(uTexture, uv);
  float y = uv.y;
  vec3 chrome = mix(vec3(0.15), vec3(0.95), smoothstep(0.0, 0.45, y));
  chrome = mix(chrome, vec3(0.2), smoothstep(0.45, 0.55, y));
  chrome = mix(chrome, vec3(1.0), smoothstep(0.55, 1.0, y));
  float sheen = 0.2 * sin(uTime * 1.5 + uv.x * 8.0) * uIntensity;
  vec3 outc = mix(s.rgb, chrome + sheen, 0.85);
  fragColor = vec4(outc, s.a);
}
