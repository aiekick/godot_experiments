shader_type spatial;

varying mat4 inv_model_matrix;
varying mat3 m1;
varying mat3 m2;

uniform sampler2D u_bump_map;

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

mat2 rot(float a)
{
    float s = sin(a);
    float c = cos(a);
    return mat2(
		vec2(c, -s), 
		vec2(s, c));
}

vec2 path(float t)
{
	return vec2(cos(t*0.08 + cos(t*0.1)*2.), sin(t*0.12 + sin(t*0.05)*2.5)) * 4.;
}

float pattern(vec3 p)
{
	p = abs(fract(p*.3) - 0.5);
	return length(max(abs(p.x), abs(p.y)) - p.z);
}

float map(vec3 p)
{
    vec2 pa = path(p.z); 
	float a = pa.x * pa.y * 0.1;
	
    p.xy -= pa;
    p.xy *= rot(a);
    
	vec3 qm1 = p*m1, qm2 = p*m2;
	
    float d0 = min(pattern(qm1), pattern(qm2));
    float d1 = min(pattern(qm1*3.), pattern(qm2*2.));
    
   	float dist0 = (1.-clamp(d0,0.,1.));
	float dist1 = (1.-clamp(d1,0.,1.))*d0;

    float di0 = length(p.xy); // tunnel
    float di1 = abs(cos(p.x*0.3)*p.y); // planes
    float di2 = 1.7 - 0.4 * cos(p.z*0.1) - abs(cos(p.x*0.5)*p.x + sin(p.y*0.5)*p.y); // planes
    
	p.z *= 0.5;
	
	vec2 cs = vec2(cos(p.z), sin(p.z)) * 0.5 + 0.5;
	
    return mix(di2, 1.47-mix(di0, di1, cs.y), cs.x) - dist0*0.75 - dist1*2.25;
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


// return color from temperature 
//http://www.physics.sfasu.edu/astro/color/blackbody.html
//http://www.vendian.org/mncharity/dir3/blackbody/
//http://www.vendian.org/mncharity/dir3/blackbody/UnstableURLs/bbr_color.html
vec3 blackbody(float Temp)
{
	vec3 col = vec3(255.);
    col.x = 56100000. * pow(Temp,(-3. / 2.)) + 148.;
   	col.y = 100.04 * log(Temp) - 623.6;
   	if (Temp > 6500.) col.y = 35200000. * pow(Temp,(-3. / 2.)) + 184.;
   	col.z = 194.18 * log(Temp) - 1448.6;
   	col = clamp(col, 0., 255.)/255.;
    if (Temp < 1000.) col *= Temp/1000.;
   	return col;
}

// get density of the df at surfPoint 
// ratio between constant step and df value
float SubDensity(vec3 p, float prec, float ms) 
{
	vec3 n;
	float s = 0.;
    for (int i=0;i<8;i++)
	{
		n = nor(p,prec); 
		p -= n * ms; 
		s += map(p);
	}
	
	return 1.-s/(ms*8.); // s < 0. => inside df
}

float SubDensityCheap(vec3 p, float s) 
{
	vec3 n = nor(p,s);
	return map(p - n * s);
}

// from shane
vec3 tex3D( sampler2D tex, in vec3 p, in vec3 n )
{
    n = max((abs(n) - .2)*7., .001);
    n /= (n.x + n.y + n.z );  
    p = (texture(tex, p.yz)*n.x + texture(tex, p.zx)*n.y + texture(tex, p.xy)*n.z).xyz;
    return p*p;
}

// from shane
vec3 doBumpMap( sampler2D tx, in vec3 p, in vec3 n, float bf)
{
    const vec2 e = vec2(0.001, 0);
    mat3 m = mat3( tex3D(tx, p - e.xyy, n), tex3D(tx, p - e.yxy, n), tex3D(tx, p - e.yyx, n));
    vec3 g = vec3(0.299, 0.587, 0.114)*m; // Converting to greyscale.
    g = (g - dot(tex3D(tx,  p , n), vec3(0.299, 0.587, 0.114)) )/e.x; g -= n*dot(n, g);
    return normalize( n + g*bf ); // Bumped normal. "bf" - bump factor.
}

vec4 shade(vec3 ro, vec3 rd, float d, vec3 lp)
{
	vec3 p = ro + rd * d;											// surface point
	float sb = SubDensity(p, 0.01, 0.1);							// deep subdensity (10 iterations)
	vec3 bb = blackbody(100.*sb+100.);								// bb
	vec3 ld = normalize(lp-p); 										// light dir
	vec3 n = nor(p, .01);											// normal at surface point
	n = doBumpMap(u_bump_map, -p*0.5, n, 0.015);
	vec3 refl = reflect(rd,n);										// reflected ray dir at surf point 
	float amb = 0.08; 												// ambiance factor
	float diff = clamp( dot( n, ld ), 0.0, 1.0 ); 					// diffuse
	float fre = pow( clamp( 1. + dot(n,rd),0.0,1.0), 16. ); 			// fresnel
	float spe = pow(clamp( dot( refl, ld ), 0.0, 1.0 ),25.);		// specular
	float sss = 1. - SubDensityCheap(p*0.1, 0.1) * 0.5; 							// one step sub density of df
	return vec4(
        (diff + fre + bb.x * sss) * amb + diff * 0.5, 
        (diff + fre + bb * sb + sss * 0.3) * amb + spe * 0.6 - diff * sss * 0.05	
    );
}

void fragment() {
	vec2 uvc = SCREEN_UV * 2.0 - 1.0;
	uvc.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(uvc, 0.0, 1.0);
	view_coords.xyz /= view_coords.w;
	vec3 world_cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_coords = (INV_VIEW_MATRIX * vec4(view_coords.xyz, 1.0)).xyz;
	vec3 ro = (inv_model_matrix * vec4(world_coords,1)).xyz;
	vec3 rd = (inv_model_matrix * vec4(normalize(world_coords - world_cam_pos),0)).xyz;
	
    mat3 mx = rotX(-7.);
	mat3 my = rotY(-5.);
	mat3 mz = rotZ(-3.);
	
    m1 = mx * my * mz;
    m2 = m1 * m1;
	
    float time = mod(TIME, 100.0) * 5.0;
    
    vec3 cu = vec3(0,1,0);
  	vec3 cv = vec3(path(time + .1),time + .1);
    
    ro = vec3(path(time),time);
    
	vec2 fov = vec2(0.5,0.5);
  	vec3 z = normalize(cv-ro);
    vec3 x = normalize(cross(cu,z));
  	vec3 y = cross(z,x);
  	rd = normalize(z + uvc.x*x*fov.x + uvc.y*y*fov.y);
	
	vec3 lp = vec3(path(time + 3.0), time + 3.0);
    
    float s = 1.;
    float d = 0.;
	
	for(int i=0;i<200;i++)
    {      
        if (d*d/s>1e6) break;
        d += s = map(ro+rd*d) * .6;
	}
	
    vec3 p = ro+rd*d;
    vec3 n = nor(p, 0.01);
    NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
		
	AO = getAmbiantOcclusion(p,n,5.5);
		
	METALLIC = 0.1;	
	ROUGHNESS = 0.3;	
		
	vec4 f = shade(ro, rd, d, lp);
	f = f.zyww + f.x*0.2;
    float fog = 1.0-exp( -0.001*d*d );
    f = mix( f, vec4(0.8), fog);
	f = mix(f, f.grba, sin(fog*5.));
	
	ALBEDO = pow(f, vec4(2.5)).rgb;
}

