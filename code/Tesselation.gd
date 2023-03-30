extends MeshInstance3D

@export var tesselation_level : float = 3.0

var rd = RenderingServer.create_local_rendering_device()
var bindings : Array
var uniform_set
var pipeline
var shader

func _ready():
	update_tesselation()
	setup_tesselation()

func _process(delta):
	render()

func setup_tesselation():
	var shader_file = load("res://shaders/Tesselation.glsl")
	var shader_spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.render_pipeline_create(shader)
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
	
func update_tesselation():	
	if not bindings.is_empty():
		var params : PackedByteArray = PackedFloat32Array([
			tesselation_level
		]).to_byte_array()
		var params_buffer = rd.storage_buffer_create(params.size(), params)
		var params_uniform := RDUniform.new()
		params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
		params_uniform.binding = 1
		params_uniform.add_id(params_buffer)
		bindings[0] = params_uniform
		uniform_set = rd.uniform_set_create(bindings, shader, 0)
	
func render():	
	var compute_list = rd.compute_list_begin()
	rd.render.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	
