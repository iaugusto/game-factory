// The tip layer's dim: the whole screen darkens except a rounded window around the spotlit
// thing, with a soft edge and a ring that pulses outward from it
// (docs/2026-09-27-style-and-tutorials/).
shader_type canvas_item;

uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);
uniform vec4 ring_color : source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform vec2 screen_size = vec2(540.0, 960.0);
uniform vec2 rect_pos = vec2(0.0);
uniform vec2 rect_size = vec2(0.0);
uniform float radius = 16.0;
uniform float has_focus = 0.0;
uniform float pulse = 0.0;

float rounded_box(vec2 p, vec2 center, vec2 half_size, float r) {
	vec2 q = abs(p - center) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * screen_size;
	float a = dim_color.a;
	vec3 rgb = dim_color.rgb;
	if (has_focus > 0.5) {
		float d = rounded_box(p, rect_pos + rect_size * 0.5, rect_size * 0.5,
				min(radius, min(rect_size.x, rect_size.y) * 0.5));
		a *= smoothstep(0.0, 8.0, d);
		// A steady rim, and a ring that travels outward and fades.
		float rim = 1.0 - smoothstep(1.0, 3.0, abs(d - 2.0));
		float wave = 1.0 - smoothstep(0.0, 2.5, abs(d - 4.0 - 22.0 * pulse));
		float ring = max(rim * 0.9, wave * (1.0 - pulse));
		rgb = mix(rgb, ring_color.rgb, ring);
		a = max(a, ring * ring_color.a);
	}
	COLOR = vec4(rgb, a);
}
