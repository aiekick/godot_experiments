/*
https://www.shadertoy.com/view/WtjGDy
*/

shader_type spatial;

varying mat4 inv_model_matrix;

void vertex() {
	inv_model_matrix = inverse(MODEL_MATRIX);
	POSITION = vec4(clamp(vec2(-1.0), vec2(1.0), UV * 2.0 - 1.0), 0.0, 1.0);
}

#define AA 1

// try with 5, for seeing the balls appearing :)
#define layers 100

#define primitiveRadius 0.5
#define voxelSize vec3(2.0)

// I got 60 fps with 20 reflections  with AA 1:) but not interesting visually
#define countReflections 2
#define transfer 5.

#define eliRadius primitiveRadius * vec3(sin(vc)*0.25+0.75)
#define torRadius primitiveRadius * vec2(1, 0.2)

vec3 camera(vec2 uv, vec3 ro, vec3 tgt)
{
    vec3 z = normalize(tgt-ro);
	vec3 x = normalize(cross(vec3(0,1,0),z));
	vec3 y = cross(z, x);
	return normalize(uv.x*x+uv.y*y+z);
}

vec3 path(float t)
{
	return vec3(0.,cos(t*0.25) * 10.0, t*2.);
}

vec3 sphNormal( in vec3 pos, in vec4 sph )
{
    return normalize(pos-sph.xyz);
}

float sphShadow( in vec3 ro, in vec3 rd, in vec4 sph )
{
    vec3 oc = ro - sph.xyz;
    float b = dot( oc, rd );
    float c = dot( oc, oc ) - sph.w*sph.w;
    return step( min( -b, min( c, b*b - c ) ), 0.0 );
}
            
vec2 sphDistances( in vec3 ro, in vec3 rd, in vec4 sph )
{
	vec3 oc = ro - sph.xyz;
    float b = dot( oc, rd );
    float c = dot( oc, oc ) - sph.w*sph.w;
    float h = b*b - c;
    float d = sqrt( max(0.0,sph.w*sph.w-h)) - sph.w;
    return vec2( d, -b-sqrt(max(h,0.0)) );
}

float sphSoftShadow( in vec3 ro, in vec3 rd, in vec4 sph )
{
    float s = 1.0;
    vec2 r = sphDistances( ro, rd, sph );
    if( r.y>0.0 )
        s = max(r.x,0.0)/r.y;
    return s;
}    
            
float sphOcclusion( in vec3 pos, in vec3 nor, in vec4 sph )
{
    vec3  r = sph.xyz - pos;
    float l = length(r);
    float d = dot(nor,r);
    float res = d;

    if( d<sph.w ) res = pow(clamp((d+sph.w)/(2.0*sph.w),0.0,1.0),1.5)*sph.w;
    
    return clamp( res*(sph.w*sph.w)/(l*l*l), 0.0, 1.0 );
}

float sphIntersect( in vec3 ro, in vec3 rd, in vec4 sph )
{
	vec3 oc = ro - sph.xyz;
	float b = dot( oc, rd );
	float c = dot( oc, oc ) - sph.w*sph.w;
	float h = b*b - c;
	if( h<0.0 ) return -1.0;
	return -b -sqrt( h );
}

// with other primitives than sphere or ellipsoid
// the reflections count cause noise issues (normal precision i thinck)
// so maybe put countReflections at 0 or tune transfer

// not very happy with the lighting :)

float getPrimitive(vec3 ro, vec3 rd, vec3 vc)
{
	return sphIntersect(ro, rd, vec4(vc, primitiveRadius));
    //return eliIntersect(ro, rd, vc, eliRadius);
    //return iGoursat(ro-vc, rd, 0.1, 0.5);
    //return iTorus(ro - vc, rd, torRadius);
}

vec3 getNor(vec3 p, vec3 vc)
{
	return sphNormal(p, vec4(vc, primitiveRadius));
    //return eliNormal(p, vc, eliRadius);
    //return nGoursat(p - vc, 0.1, 0.5);
	//return nTorus(p - vc, torRadius);
}

float getDist(vec3 ro, vec3 rd, vec3 vs, out vec3 vc)
{
	float ds = -1.0;
	
	vec3 p = ro;
    for (int i=0;i<layers;i++)
	{
		vc = (floor(p / vs) + 0.5) * vs; // voxel center
		ds = getPrimitive(ro, rd, vc); 	 // distance to analytic primitve
        if (ds > 0.0) break; 	         // hit => exit
		p += rd * vs;			         // move point to next voxel along ray if no hit
	}
    
    // for render when no hit after all layers
	if (ds < 0.0)
		ds = float(layers);
	
	return ds;
}

vec3 shade(vec3 ro, vec3 rd, vec3 vc)
{
    vec3 p = ro;
	vec3 n = getNor(p, vc);
	
    vec3 ld = vec3(-0.25, -1, 0.25);
	
    float diff = dot(n, ld) * .5 + .5;
	float spe = pow(max(dot(-rd, reflect(-ld, n)), 0.0), 8.0);
	float fre = pow( clamp( 1. + dot(n,rd),0.0,1.0), 4. );
	    
    vec3 c = (n * 0.5 + 0.5) * diff; // basic coloring :)
    c += fre * 0.25 + spe * 0.5;

	return c;	
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

	vec3 vc = vec3(0); // voxel center
	float ds = getDist(ro, rd, voxelSize, vc);
	float fog = 1.0-exp(-0.0002*ds*ds); // fog with first hit

	vec3 p = ro + rd * ds;
	vec3 n = getNor(p, vc);
	vec4 ndc = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
	//float ao = getAmbiantOcclusion(p, n, 6.98795);
	//float ratio = clamp((1.0 - ao) * 3.07229, 0.0, 1.0);
			
	DEPTH = ndc.z / ndc.w;
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	METALLIC = 0.3;	
	ROUGHNESS = 0.3;
	//AO = ratio;
	
    // first coloring
    color = shade(p, rd, vc);
	
    // reflections
	float d = ds; 
	for (int i=0;i<countReflections;i++)
	{
		vec3 n = getNor(p, vc);
		rd = reflect(rd, n);
		ds = getDist(p, rd, voxelSize, vc);
		d *= ds;
		p += rd * ds;
		color = mix(color, shade(p, rd, vc), transfer / d);
	}
	
    ALBEDO = clamp(mix(color, vec3(0), fog),0.,1.);
}
