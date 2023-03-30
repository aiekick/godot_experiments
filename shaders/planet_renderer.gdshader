shader_type spatial;

uniform sampler2D u_height_map;
uniform sampler2D u_color_map;

varying vec2 v_UV;
varying mat4 inv_model_matrix;

void vertex() {
	v_UV = UV;
	inv_model_matrix = inverse(MODEL_MATRIX);
	POSITION = vec4(UV * 2.0 - 1.0, 0, 1);
}

// Created by sebastien durand - 04/2020
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
//-------------------------------------------------------

// Relief (low = big!) values : [2..20]
#define H_COEFF 5.

// With / Without water 
#define WITH_WATER

#define WATER_OPACITY_COEFF 2.5
#define WATER_OPACITY_INIT 1.

#define WITH_MOUSE_CONTROL 

#define WITH_SHADOWS
#define WITH_AO  // Good with a lot of rays but need multi pass
#define NB_AO  4 // Reduce if slow


// -------------------------------
// DO NOT CHANGE
// -------------------------------


#define PI 3.14159265359

#define NO_ID 0
#define GROUND_ID 1
#define DEEP_ID 2

#define NO_INTERSECTION 9999.


#define COLOR_BACK vec3(.42,.46,.48)
#define COLOR_WATER vec3(.3, .12, .08) 
 
const float dd = .02;     // ray step 

// ------------------------------------------------------------------------------

int intersectSphere(vec3 ro, vec3 rd, float r, out float t1, out float t2) {
    float b = dot(ro,rd), d = b*b - dot(ro,ro) + r*r;
    if (d <= 0.) return -1;
    t1 = -b-sqrt(d);
    t2 = -2.*b-t1;
	if (t1 > 0.0) {
		return 1;
	} else {
		if (t2 > 0.0) {
			return 2;
		}
	}
	return 0;
}

vec3 toSpherical(vec3 p) {
    float r = length(p);
    return vec3(asin(p.z/r),               // lat
                atan(p.y, p.x)+PI,         // lon
                H_COEFF*(r-1.)); // alti (meters data)
}

// -------------------------------------------------------------------

float hash1( float seed) {
    return fract(sin(seed)*43758.545312);
}

vec2 hash2( float seed) {
    return fract(sin(vec2(seed*43758.545312,(seed+.1)*22578.145912)));
}

float hash( const in vec3 p ) {
    return fract(sin(dot(p,vec3(127.1,311.7,758.5453123)))*43758.5453123);
}

// ------------------------------------------------------------------

float altitudeMeter(vec3 p) {
    vec3 s = toSpherical(p);
    vec2 p2 = s.yx/PI;  // Lon, Lat, H in Grib
    
	return texture(u_height_map, toSpherical(p).xy).r;
}

float altitude(vec3 p) {
    return H_COEFF*(length(p)-1.)-altitudeMeter(p)/100.;
}

vec3 normalAt( vec3 p) {
    vec3 e = vec3 (.001, -.001, 0); 
    return normalize(e.xyy * altitude(p + e.xyy)
                   + e.yyx * altitude(p + e.yyx)
                   + e.yxy * altitude(p + e.yxy)
                   + e.xxx * altitude(p + e.xxx));
}

// bisect
float preciseSurfaceGround( vec3 ro,  vec3 rd, float dmin, float dmax) {
    float dm = dmin;
    vec3 p; 
    for (int j=0; j<6;j++) {
        dm = (dmin + dmax)*.5;  
        p = ro+rd*dm;
        if (altitude(p) < 0.) dmax = dm;  
        else dmin = dm;
    }
    return dm;  
}

vec2 rayGround(vec3 ro,  vec3 rd,  float dmin,  float dmax, out vec3 out_n, out float out_val) {
    
    float t1, t2;
    // Test bounding sphere
    int type = intersectSphere(ro, rd, .5/H_COEFF+1., t1, t2);
    if (type > 0) {
        dmin = max(dmin,t1);
        dmax = min(dmax,t2);

        // Go step by step until the ray traverse the ground
        float d, h, rand = dd*hash1(dot(ro+rd*dmin,vec3(127.1,311.7,758.5453123)));
        for(float _d = dmin+rand; _d<dmax+dd; _d += dd) {
			d = _d;
            h = altitude(ro+rd*d);
            if (h <= 0.) break;
        }

        // Precise the true intersection point
        if (d <= dmax) {
            d = preciseSurfaceGround(ro, rd, max(dmin, d-dd), min(d,dmax));
            out_n = normalAt(ro+rd*d);				
            out_val = altitude(ro+rd*d);
            return vec2(d, GROUND_ID);
        }
    }
	return vec2(NO_INTERSECTION, NO_ID);
}


#ifdef WITH_SHADOWS
float doShadow( vec3 ro,  vec3 rd,  float dMax) {
    vec3 n;
    float val, dMin = dd*.1;
    vec2 res = rayGround(ro, rd, dMin, dMax, n, val);
    return res.x>dMin && res.x <= dMax ? 1. - clamp((dMax-res.x)/dMax,0.,1.) : 1.;
}
#endif


#ifdef WITH_AO
vec3 randomHemisphereDirection(vec3 n,  float seed) {
    vec2 r = 2.*PI*hash2(seed);
    vec3 dr = vec3(sin(r.x)*vec2(sin(r.y),cos(r.y)),cos(r.x));
    float k = dot(dr,n);
    return k == 0. ? n : normalize(k*dr);
}

float doAmbiantOcclusion( vec3 ro,  vec3 n, float dMax) {
    float val, ao = 0., seed = ro.x+ro.y+.12345*ro.z;
    vec3 n2, rd;
    vec2 res;
    for (int i=0;i<NB_AO; i++){
        rd = randomHemisphereDirection(n, seed);    
        seed += .1;
        res = rayGround(ro, rd, .03*dd, 1., n2, val);
        if (int(res.y) != NO_ID && res.x > 0. && res.x < dMax) {
            ao += clamp((dMax-res.x)/dMax,0.,1.);
        }
    }
    return (1.-ao/float(NB_AO));
}
#endif


// -----------------------------------------------------------------

// Shading
vec3 doShading(int id, vec3 rd, vec3 p, vec3 n, vec3 light,  vec3 col) { 
    float diffuse = max(0., dot(n, light)),
          rimMatch =  1. - max( 0. , dot( n , -rd ) );
    vec3 rimCol  = vec3 (.4,.6,1.)*rimMatch;

    float occ = 1.;
#ifdef WITH_AO
    occ = doAmbiantOcclusion(p+n*.001/*.01*rd*dd*/, n, .08);
#endif
     
    vec3 hal = normalize( light-rd );
	float 
        amb = clamp( .5, 0., 1. ),
     	dif = clamp( dot( n, light ), 0., 1. ),
     	bac = clamp( dot( n,-light), 0., 1. ),
     	fre = pow( clamp(1.0+dot(n,rd),0.,1.), 2. );
        
#ifdef WITH_SHADOWS
    if (dif >0.) {
        dif *= (doShadow(p-.2*rd*dd, light, .6));  
    }
#endif

	vec3 lin = vec3 (0.);
    lin += .7*dif*vec3 (1.,.8,.55);
    lin += .4*amb*vec3 (.4,.6,1.)*occ;
    lin += .5*bac*vec3 (.25)*occ;
    lin += .25*fre*vec3 (1)*occ;

    float spe = max(0., dot(light, reflect(rd, n)));
    spe = dif*pow(spe,29.);;              

	vec3 c = col*lin;
	c += (id==GROUND_ID?.1f:.5f)*spe;
    c+= .2f * rimCol * occ;

    return pow(c,vec3(.55f)); 	   
}


// Camera
vec3 RD( vec3 ro, vec3 ta, vec3 up, vec2 uv, vec2 res, float h) {
    vec2 p = (2.*uv-res)/res.y;
    vec3 
        w = normalize(ta - ro),
        u = normalize(cross(w, up)),
        v = normalize(cross(u,w));
    return normalize( p.x*u + p.y*v + h*w );
}

void fragment() {
    vec2 q = SCREEN_UV * 2.0 - 1.0;
    vec3 col = COLOR_BACK * pow(16.*q.x*q.y*(1.-q.x)*(1.-q.y),.3f)
    		 + .05*hash(vec3(q,1.));

    // Camera
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(q, 0.0, 1.0);
	view_coords.xyz /= view_coords.w;
	vec3 world_cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_coords = (INV_VIEW_MATRIX * vec4(view_coords.xyz, 1.0)).xyz;
	vec3 ro = (inv_model_matrix * vec4(world_coords,1)).xyz;
	vec3 rd = (inv_model_matrix * vec4(normalize(world_coords - world_cam_pos),0)).xyz;
	
    // Light
    vec3 n,p, lightDir = normalize(ro+vec3(0,10,10));

    // Find intersection
	float val, tmax = 5.f;
    vec2 res = rayGround(ro, rd, 0., tmax, n, val);

    // Shading
    if (res.x > 0. && res.x < NO_INTERSECTION) {
       
        if (int(res.y) == GROUND_ID) {
            p = ro + res.x*rd;
			float h = altitudeMeter(p);
 
            col = mix(.2*vec3(.6,.5,.4), texture(u_color_map, vec2(h/50.,.5)).xyz, .7);
            col *= .8 +.3*hash(p); // a little bit dirty
            col = pow(col, vec3(.7));
			
#ifdef WITH_WATER
            vec3 colw = texture(u_color_map, vec2(0)).xyz; 
            colw = colw*.25 + .75*exp(-COLOR_WATER*(-h*.002)); 
            col = mix(colw,col, smoothstep(-0.1,0.1,h));
#endif
            col = doShading(int(res.y), rd, p, n, lightDir, col);
        }
    }
    
#ifdef WITH_WATER
	// Add water effect
	float dminSea, dmaxSea;
    if (intersectSphere(ro, rd, 1., dminSea, dmaxSea)>0) {
        if (dminSea <= res.x) {
            p = ro+rd*dminSea;
            float dist = min(res.x,dmaxSea) - dminSea;
            col = col * exp(-COLOR_WATER*(WATER_OPACITY_INIT + 20.*WATER_OPACITY_COEFF*dist));
            n = normalize(p);
            float specular = max(0., dot(lightDir, reflect(rd, n)));
            specular = pow(specular,29.);
            col += .4*specular;
        }
    }
#endif

    ALBEDO = col;
}
