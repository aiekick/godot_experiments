shader_type spatial;

void vertex() {
	POSITION = PROJECTION_MATRIX * vec4(VERTEX / (VIEW_MATRIX[3].z), 0);
	POSITION.w = 1.0;
}

void fragment() {
	ALBEDO = vec3(0.8,0.5,0.2);
}
