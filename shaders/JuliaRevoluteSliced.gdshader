shader_type spatial;

varying mat4 inv_model_matrix;
uniform float countSlices : hint_range(1, 100) = 30.0;
uniform vec3 color : source_color = vec3(0.4,0,0);
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

#define ANGLE_CUTTER
//#define RADIUS_CUTTER

// a bit noisy
//#define HEIGHT_CUTTER


float fullAtan(vec2 p)
{
    return step(0.0,-p.x) * 3.14159 + sign(p.x) * atan(p.x, sign(p.x) * p.y);
}

float julia(vec2 p, vec2 v)
{
	vec2 z = p;
    vec2 c = v;
	float k = 1., h = 1.0;    
    for (int i=0;i<5;i++)
    {
        h *= 4.*k;
		k = dot(z,z);
        if(k > 4.) break;
		z = vec2(z.x * z.x - z.y * z.y, 2. * z.x * z.y) + c;
    }
	return sqrt(k/h)*log(k);
}

float fractusSliced(vec3 p, float a, float n, float oa)
{
#ifdef HEIGHT_CUTTER
    p.y += oa/n;
	float cutterHeight = abs(abs(fract(p.y*n)-0.5) - 0.225)-0.225;
	p.y = floor(p.y*n)/n;	
#endif
#ifdef ANGLE_CUTTER
    a += oa/n;
	float cutterAngle = abs(abs(fract(a*n)-0.5) - 0.225)-0.225;
	a = floor(a*n)/n;	
#endif
    vec2 c = vec2(mix(0.2, -0.5, sin(a * 2.)), mix(0.5, 0.0, sin(a * 3.)));   
    float path = length(p.xz) - 3.;
#ifdef RADIUS_CUTTER
    path += oa/n;
	float cutterRadius = abs(abs(fract(path*n)-0.5) - 0.225)-0.225;
	path = floor(path*n)/n;	
#endif
    vec2 rev = vec2(path, p.y);
    float aa = a + mod(TIME, k2Pi);
    rev *= mat2(
		vec2(cos(aa),-sin(aa)),
		vec2(sin(aa),cos(aa))); // rot near axis y
    float d = julia(rev, c);
#ifdef HEIGHT_CUTTER
    d = max(cutterHeight,d);
#endif
#ifdef ANGLE_CUTTER
    d = max(cutterAngle,d);
#endif
#ifdef RADIUS_CUTTER
    d = max(cutterRadius,d);
#endif
	return d;
}

float dfFractus(vec3 p)
{
	float a = fullAtan(p.xz);
	return min(
        fractusSliced(p,a,countSlices,0.), 
        fractusSliced(p,a,countSlices,0.5));
}

float map(vec3 p)
{
	return dfFractus(p * 0.5);
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
	
    float md = 100.0;
	float d = 0.0;
	float s = 1.0;
	vec3 p = ro;
	for (int i = 0; i < 500; ++i)
	{
		if (d*d/s>1e5 || d > md) break;
		s = map(ro + rd * d);
		d += s * 0.15;
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
        ALBEDO = color;		
		METALLIC = 1.0;	
		ROUGHNESS = 0.0;	
		AO = ratio;
	}
	else
	{
		discard;
	}
}
