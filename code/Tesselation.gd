extends MeshInstance3D

var tesselation_level : float = 3.0
var rd = RenderingServer.create_local_rendering_device()
var bindings : Array
var uniform_set
var pipeline
var shader

func _ready():
	setup_tesselation()
	render()

func _process(delta):
	# update_tesselation()
	render(delta)

func setup_tesselation():
	var shader_file = load("res://shaders/Tesselation.glsl")
	var shader_spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)
	var params : PackedByteArray = PackedFloat32Array([
		tesselation_level
	]).to_byte_array()
	var params_buffer = rd.uniform_buffer_create(params.size(), params)
	var params_uniform := RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	params_uniform.binding = 1
	params_uniform.add_id(params_buffer)
	bindings = [ params_uniform ]
	uniform_set = rd.uniform_set_create(bindings, shader, 0)
	
# func update_tesselation():
	
func render(delta : float = 0.0):	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	
