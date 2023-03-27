shader_type spatial;

void vertex() {
	POSITION = vec4(UV * 2.0 - 1.0, 0.0, 1.0);
}

float map(vec3 p)
{
	return length(p) - 1.0;
}

vec3 nor(vec3 p, float prec)
{
	vec3 e = vec3(prec, 0.0, 0.0);
	return normalize(vec3(
		map(p+e.xyz) - map(p-e.xyz),
		map(p+e.zxy) - map(p-e.zxy),
		map(p+e.yzx) - map(p-e.yzx)));
}

void fragment() {
	vec2 uvc = SCREEN_UV * 2.0 - 1.0;
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(uvc, 0.0, 1.0);
	view_coords.xyz /= view_coords.w;
	vec3 world_cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_coords = (INV_VIEW_MATRIX * vec4(view_coords.xyz, 1.0)).xyz;
	
	vec3 ro = world_coords.xyz;
	
	vec4 ray_clip = vec4(uvc.x, uvc.y, -1., 1.);
	vec4 ray_eye = inverse(PROJECTION_MATRIX) * ray_clip;
	//vec3 rd = normalize(vec3(ray_eye.x, ray_eye.y, -1.));
	//rd *= mat3(VIEW_MATRIX * MODEL_MATRIX);
	vec3 rd = normalize(world_coords - world_cam_pos);
	
	float md = 100.0;
	float d = 0.0;
	float s = 1.0;
	vec3 p = ro;
	for (int i = 0; i < 100; ++i)
	{
		if (d*d/s>1e7 || d > md) break;
		s = map(ro + rd * d);
		d += s;
	}
	
	if (d < md)
	{
		vec3 p = ro + rd * d;
		vec3 normal = nor(p, 0.01);
		vec4 sdf_ndc = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
		DEPTH = sdf_ndc.z / (sdf_ndc.w + 0.00001);
		NORMAL = (VIEW_MATRIX * vec4(normal, 0.0)).xyz;
		ALBEDO = normal * 0.5 + 0.5;
	}
	else
	{
		discard;
	}
}
