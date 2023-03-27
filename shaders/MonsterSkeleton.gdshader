shader_type spatial;

varying mat3 scene_mtx;
varying mat4 inv_model_matrix;
uniform vec3 color_start = vec3(0.4,0,0);
uniform vec3 color_end = vec3(0.46,0.42,0.21);
uniform vec2 shape_mouse = vec2(0.468359,0.95317);

void vertex() {
	inv_model_matrix = inverse(MODEL_MATRIX);
	POSITION = vec4(UV * 2.0 - 1.0, 0.0, 1.0);
}

const float kPi = 3.1415926535897932384626433832795;
const float k2Pi = 6.283185307179586476925286766559;

mat3 rotZ(float t)
{
    float s = sin(t);
    float c = cos(t);
    return mat3(
		vec3(c, s, 0.0), 
		vec3(-s, c, 0.0), 
		vec3(0., 0., 1.));
}

mat3 rotX(float t)
{
    float s = sin(t);
    float c = cos(t);
    return mat3(
		vec3(1.0, 0.0, 0.0), 
		vec3(0.0,	c, 	s), 
		vec3(0.0, -s, c));
}

mat3 rotY(float t)
{
    float s = sin(t);
    float c = cos(t);
    return mat3(
		vec3(c, 0.0, -s), 
		vec3(0.0, 1.0, 0.0), 
		vec3(s, 0.0, c));
}

float map(vec3 p)
{
	float scaleAccum = 1.;
    for(int i = 0; i < 18; ++i)
    {
		p.yz = sqrt(p.yz*p.yz+0.4);
		p *= 1.21;
		scaleAccum *= 1.21;
        p -= vec3(2.43307,5.28488,0.9685);
        p = scene_mtx * p;
	}
	
	return length(p) / scaleAccum - 0.15;
}

float getAmbiantOcclusion(vec3 p, vec3 n, float k)
{				
    float o = 0.0, d = 0.0;
    for(float diff = 0.0, c = 0.0; diff < 6.0; diff+=0.1, ++c)
    {
        d = map(p + n * diff);
        o += (diff - d) * pow(2., float(-c));
    }
    return min(1., 1. - k * o);
}

float getShadow(vec3 ro, vec3 rd, float minD, float maxD, float k)
{
    float res = 1.0;
    float d = minD;
	float s = 0.;
    for(int i = 0; i < 50; ++i)
    {
        s = map(ro + rd * d);
        if( abs(s) < d*d*1e-5 ) return 0.0;
        res = min( res, k * s / d );
		d += s;
        if(d >= maxD) break;
    }
    return res;
}

vec3 acesFilm(const vec3 x, float a, float b, float c, float d, float e) 
{
    return clamp((x * (a * x + b)) / (x * (c * x + d ) + e), 0.0, 1.0);
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
	vec3 ro = (inv_model_matrix * vec4(world_coords,1)).xyz;
	vec3 rd = (inv_model_matrix * vec4(normalize(world_coords - world_cam_pos),0)).xyz;
	
    vec2 rm = k2Pi * shape_mouse;
	scene_mtx = rotX(rm.x) * rotY(rm.x) * rotZ(rm.x) * rotX(rm.y);
	
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
		vec3 n = nor(p, 0.01);
		vec4 ndc = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
		float ao = getAmbiantOcclusion(p, n, 6.98795);
		float ratio = clamp((1.0 - ao) * 3.07229, 0.0, 1.0);
		
		DEPTH = ndc.z / ndc.w;
		NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
        ALBEDO =  mix(color_start, color_end, vec3(ratio));		
		METALLIC = 1.0;
		ROUGHNESS = 1.0 - ratio;		
		AO = ratio;
	}
	else
	{
		discard;
	}
}
