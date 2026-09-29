shader_type canvas_item;
// Enemies are drawn from a two-frame walk atlas (frames side by side), batched in a
// MultiMesh. Per-instance custom data: r = hit flash (0..1, toward white), g = walk frame
// (0 or 1), b = frost: 0 none, 0.5 slowed (an icy overlay), 1 frozen solid (the body turns to
// blue ice). The instance colour fades (alpha). (Custom data's alpha doesn't arrive on the
// compatibility renderer, so frost and ice share b.)

varying vec3 custom;

void vertex() {
	custom = INSTANCE_CUSTOM.rgb;
	UV.x = UV.x * 0.5 + step(0.5, custom.g) * 0.5;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	vec3 icy = vec3(0.55, 0.85, 1.0) * (0.35 + lum * 0.9);
	vec3 rgb = mix(c.rgb, icy, step(0.25, custom.b) * 0.65);
	rgb = mix(rgb, vec3(1.0), custom.r);
	// COLOR comes in as texture × instance colour, so the ice goes on after that product (a
	// blue block multiplied by an orange body would turn beige).
	vec3 lit = rgb * COLOR.rgb;
	vec3 ice = mix(vec3(0.3, 0.62, 0.95), vec3(0.88, 0.98, 1.0), clamp(lum * 1.3, 0.0, 1.0));
	lit = mix(lit, ice, step(0.75, custom.b) * 0.8);
	COLOR = vec4(lit, c.a * COLOR.a);
}
