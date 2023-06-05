/*
https://www.shadertoy.com/view/4s3XRB
*/

shader_type spatial;

varying mat4 inv_model_matrix;

void vertex() {
	inv_model_matrix = inverse(MODEL_MATRIX);
	POSITION = vec4(clamp(vec2(-1.0), vec2(1.0), UV * 2.0 - 1.0), 0.0, 1.0);
}

#define AA 1

const vec3 ld = vec3(0.,1., .5);
varying float dstepf;
varying float t;

vec2 path(float z){return sin(z*.2 + vec2(1.6,0));}

mat3 getRotXMat(float a){return mat3(vec3(1.,0.,0.),vec3(0.,cos(a),-sin(a)),vec3(0.,sin(a),cos(a)));}
mat3 getRotYMat(float a){return mat3(vec3(cos(a),0.,sin(a)),vec3(0.,1.,0.),vec3(-sin(a),0.,cos(a)));}
mat3 getRotZMat(float a){return mat3(vec3(cos(a),-sin(a),0.),vec3(sin(a),cos(a),0.),vec3(0.,0.,1.));}

float fractus(vec3 p)
{
	vec2 z = p.xy;
    vec2 c = vec2(-1.04,-0.36) * vec2(cos(p.z), sin(p.z));
	float k = 1., h = 1.0;    
    for (float i=0.;i<6.;i++)
    {
		h *= 4.*k;
		k = dot(z,z);
		if (k > 4.) break;
        z = vec2(z.x * z.x - z.y * z.y, 2.* z.x * z.y) + c;
    }
	return  sqrt(k/h)*log(k);   
}

float df(vec3 p)
{
	vec3 tutu;
	
   	vec3 pz = p;
    pz.z += 0.;
    pz.xy = mod(pz.xy, 8.) - 8.*0.5;
	pz *= getRotZMat(sin(pz.z*0.));
	tutu.x = min(1.,fractus(pz.xyz));

	vec3 py = p;
	py.y += 0.;
    py.xz = mod(py.xz, 8.) - 8.*0.5;
	py *= getRotYMat(sin(py.y*0.));
	tutu.y = min(1.,fractus(py.xzy));
	
	vec3 px = p;
    px.x += 0.;
	px.z += -0.5;
    px.yz = mod(px.yz, 8.) - 8.*0.5;
	px *= getRotXMat(sin(px.x*0.));
	tutu.z = min(1.,fractus(px.yzx));

	float k = tutu.x*tutu.y*tutu.z;
	return k;
}

vec3 nor( vec3 p, float prec )
{
    vec2 e = vec2( prec, 0. );
    vec3 n = vec3(
		df(p+e.xyy) - df(p-e.xyy),
		df(p+e.yxy) - df(p-e.yxy),
		df(p+e.yyx) - df(p-e.yyx) );
    return normalize(n);
}

// from iq code
float softshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax )
{
	float res = 1.0;
    float tt = mint;
    for( int i=0; i<18; i++ )
    {
		float h = df( ro + rd*t );
        res = min( res, 8.0*h/tt );
        tt += h*.25;
        if( h<0.001 || tt>tmax ) break;
    }
    return clamp( res, 0., 1. );
}

// from iq code
float calcAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
    float sca = 1.0;
    for( int i=0; i<10; i++ )
    {
        float hr = 0.01 + 0.12*float(i)/4.0;
        vec3 aopos =  nor * hr + pos;
        float dd = df( aopos );
        occ += -(dd-hr)*sca;
        sca *= 0.95;
    }
    return clamp( 1.0 - 3.0*occ, 0.0, 1.0 );    
}

vec3 lighting(vec3 p, vec3 lp, vec3 rd, float prec) 
{
    vec3 l = lp - p;
    float d = max(length(l), 0.01);
    float atten = 1.0-exp( -0.01*d*d );
    l /= d;
    
    vec3 n = nor(p, prec);
   	vec3 r = reflect(-l, n);
    
    float dif = clamp(dot(l, n), 0.0, 1.0);
    float spe = pow(clamp(dot(r, -rd), 0.0, 1.0), 8.0);
    float fre = pow(clamp(1.0 + dot(n, rd), 0.0, 1.0), 2.0);
    float dom = smoothstep(-1.0, 1.0, r.y);
    
    dif *= softshadow(p, rd, 0.1, 1.);
    
    vec3 lin = vec3(0.08,0.32,0.47);
    lin += 1.0*dif*vec3(1,1,0.84);
    lin += 2.5*spe*dif*vec3(1,1,0.84);
    lin += 2.5*fre*vec3(1);
    lin += 0.5*dom*vec3(1);
    
    return lin * atten * calcAO(p, n);
}

float trace( in vec3 ro, in vec3 rd)
{
	float s = 1.;
	float d = 0.;
	vec3 p = ro;
	
	for (float i=0.; i<150.; i++)
	{
		if (s < 0.025*log(d*d/s/500.) || d>40.) break; // last change was d*d
		s = df(p);
		d += s * 0.2;
		p = ro + rd * d;
	}
	
    return d;
}

void fragment() {
	vec2 uvc = clamp(vec2(-1.0), vec2(1.0), SCREEN_UV * 2.0 - 1.0);
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(uvc, 0.0, 1.0);
	view_coords.xyz /= view_coords.w;
	vec3 world_cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_coords = (INV_VIEW_MATRIX * vec4(view_coords.xyz, 1.0)).xyz;
	vec3 ro = (inv_model_matrix * vec4(world_coords,1)).xyz;
	vec3 rd = (inv_model_matrix * vec4(normalize(world_coords - world_cam_pos),0)).xyz;
	vec3 color = vec3(0);
	
	ro.y += MODEL_MATRIX[3].y;

	float d = trace(ro, rd);
	if (d < 40.0 )
	{
		vec3 p = ro + rd * d;	
		vec3 n = nor(p, 0.01);
	
	    float fogd = 0.01;
		
		vec4 ndc = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
				
		DEPTH = ndc.z / ndc.w;
		NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
		METALLIC = 1.0;	
		ROUGHNESS = 0.3;
	}
}
