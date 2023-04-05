shader_type spatial;

uniform float u_h_coeff : hint_range(2.0, 20.0, 0.1) = 5.0;

varying mat4 inv_model_matrix;
varying mat4 inv_proj_matrix;
varying mat4 inv_view_matrix;

uniform sampler2D u_color_map;
uniform sampler2D u_height_map;
uniform sampler2D u_mask_map;
uniform sampler2D u_cloud_map;
uniform sampler2D u_sdf_map;

varying vec3 v_pos;
varying vec2 v_uv;

void vertex() {
	inv_model_matrix = inverse(MODEL_MATRIX);
	inv_proj_matrix = INV_PROJECTION_MATRIX;
	inv_view_matrix = INV_VIEW_MATRIX;
	v_pos = VERTEX;
	v_uv = UV;
}

void cam(in vec2 uvc, out vec3 ro, out vec3 rd)
{
	vec4 view_coords = inv_proj_matrix * vec4(uvc, 0.0, 1.0);
	view_coords.xyz /= view_coords.w;
	vec3 world_cam_pos = (inv_view_matrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_coords = (inv_view_matrix * vec4(view_coords.xyz, 1.0)).xyz;
	ro = (inv_model_matrix * vec4(world_coords,1)).xyz;
	rd = (inv_model_matrix * vec4(normalize(world_coords - world_cam_pos),0)).xyz;
}

vec3 toSpherical(vec3 p) {
    float r = length(p);
    return vec3(asin(p.z/r),				// lat
                atan(p.y, p.x) + PI,		// lon
                u_h_coeff * (1.0-r));		// alti (meters data)
}

vec2 getUV(vec3 p)
{
	p = normalize(p);
	vec2 uv_map;
	uv_map.x = atan(p.x, p.z) / (2.0 * PI) + 0.5;
	uv_map.y = asin(-p.y) / PI + 0.5;
	uv_map = clamp(uv_map, 0.0, 1.0);
	return uv_map;
}

void fragment() {
	vec2 uvc = SCREEN_UV * 2.0 - 1.0;
	vec3 ro, rd; cam(uvc, ro, rd);
	float d = length(ro - v_pos);
	vec3 p = ro + rd * d;
	
	vec2 uv_map = fract(getUV(p));
	vec3 color = texture(u_color_map, uv_map).rgb;
	float mask = texture(u_mask_map, uv_map).r;
	float height = texture(u_height_map, uv_map).r;
	float cloud = texture(u_cloud_map, uv_map).r;
	
	ALBEDO = sqrt(color*color*0.3);
	if (mask > 0.5) {
		ALBEDO = vec3(0,0,0.15);
		ROUGHNESS = 0.2;
		
		float st = 0.2;
		float sd = 0.0;
		vec2 uv_it;
		for (int i = 0; i < 300; ++i) {
			p = ro + rd * (d + sd);
			uv_it = getUV(p);
			vec3 tex_col = texture(u_mask_map, uv_it).rgb;
			float ct = min(tex_col.r, min(tex_col.g, tex_col.b));
			if (ct > 0.5) {
				ALBEDO = texture(u_color_map, uv_it).rgb * (1.0 - sd / 100.0);
			}
			sd += st;
		}
		
		//discard;
	}
	
	/*if (cloud > 0.9) {
		ALBEDO = vec3(cloud);
	}*/

}
