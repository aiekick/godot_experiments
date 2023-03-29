#[tesselation_control]
#version 450

layout (vertices = 3) out;

layout(location = 0) in vec3 vertex_attrib[];
layout(location = 1) in vec2 normal_attrib[];
layout(location = 2) in vec2 tangent_attrib[];
layout(location = 3) in vec4 color_attrib[];
layout(location = 4) in vec2 uv_attrib[];

layout(location = 0) out vec3 vertex_attrib_tess_control[];
layout(location = 1) out vec2 normal_attrib_tess_control[];
layout(location = 2) out vec2 tangent_attrib_tess_control[];
layout(location = 3) out vec4 color_attrib_tess_control[];
layout(location = 4) out vec2 uv_attrib_tess_control[];

layout(set = 0, binding = 0, std140) uniform tesscUBO
{
    float level;
} tessc;

void main()
{
    vertex_attrib_tess_control[gl_InvocationID] = vertex_attrib[gl_InvocationID];
	normal_attrib_tess_control[gl_InvocationID] = normal_attrib[gl_InvocationID];
	tangent_attrib_tess_control[gl_InvocationID] = tangent_attrib[gl_InvocationID];
	color_attrib_tess_control[gl_InvocationID] = color_attrib[gl_InvocationID];
	uv_attrib_tess_control[gl_InvocationID] = uv_attrib[gl_InvocationID];
	
	if (gl_InvocationID == 0)
	{
		gl_TessLevelOuter[0] = tessc.level;
		gl_TessLevelOuter[1] = tessc.level;
		gl_TessLevelOuter[2] = tessc.level;
		gl_TessLevelOuter[3] = tessc.level;
		
		gl_TessLevelInner[0] = tessc.level;
		gl_TessLevelInner[1] = tessc.level;
	}
} 

#[tesselation_evaluation]
#version 450

layout(triangles, equal_spacing, ccw) in;

layout(location = 0) in vec3 vertex_attrib_tess_control[];
layout(location = 1) in vec2 normal_attrib_tess_control[];
layout(location = 2) in vec2 tangent_attrib_tess_control[];
layout(location = 3) in vec4 color_attrib_tess_control[];
layout(location = 4) in vec2 uv_attrib_tess_control[];

layout(location = 0) out vec3 vertex_attrib;
layout(location = 1) out vec2 normal_attrib;
layout(location = 2) out vec2 tangent_attrib;
layout(location = 3) out vec4 color_attrib;
layout(location = 4) out vec2 uv_attrib;

vec4 interpolateV4(vec4 v0, vec4 v1, vec4 v2)
{
    return gl_TessCoord.x * v0 + gl_TessCoord.y * v1 + gl_TessCoord.z * v2;
} 

vec3 interpolateV3(vec3 v0, vec3 v1, vec3 v2)
{
    return gl_TessCoord.x * v0 + gl_TessCoord.y * v1 + gl_TessCoord.z * v2;
} 

vec2 interpolateV2(vec2 v0, vec2 v1, vec2 v2)
{
    return gl_TessCoord.x * v0 + gl_TessCoord.y * v1 + gl_TessCoord.z * v2;
} 

void main()
{
    vertex_attrib = interpolateV3(vertex_attrib_tess_control[0], vertex_attrib_tess_control[1], vertex_attrib_tess_control[2]);
	normal_attrib = interpolateV2(normal_attrib_tess_control[0], normal_attrib_tess_control[1], normal_attrib_tess_control[2]);
	tangent_attrib = interpolateV2(tangent_attrib_tess_control[0], tangent_attrib_tess_control[1], tangent_attrib_tess_control[2]);
	color_attrib = interpolateV4(color_attrib_tess_control[0], color_attrib_tess_control[1], color_attrib_tess_control[2]);
	uv_attrib = interpolateV2(uv_attrib_tess_control[0], uv_attrib_tess_control[1], uv_attrib_tess_control[2]);
	
	gl_Position = vec4(vertex_attrib, 1.0);
} 