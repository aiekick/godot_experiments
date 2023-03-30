shader_type spatial;

varying vec3 v_pos;

void vertex() {
	v_pos = VERTEX;	
}
void fragment() {
	NORMAL = normalize(cross(dFdx(v_pos), dFdy(v_pos)));
}
