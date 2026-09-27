shader_type canvas_item;
// Enemies are drawn from a two-frame walk atlas (frames side by side), batched in a
// MultiMesh. Per-instance custom data: r = hit flash (0..1, toward white), g = walk frame
// (0 or 1), b = frost (0..1, an icy overlay while slowed). The instance colour fades (alpha).

varying vec3 custom;

void vertex() {
	custom = INSTANCE_CUSTOM.rgb;
	UV.x = UV.x * 0.5 + step(0.5, custom.g) * 0.5;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	vec3 icy = vec3(0.55, 0.85, 1.0) * (0.35 + lum * 0.9);
	vec3 rgb = mix(c.rgb, icy, custom.b * 0.65);
	rgb = mix(rgb, vec3(1.0), custom.r);
	COLOR = vec4(rgb * COLOR.rgb, c.a * COLOR.a);
}
