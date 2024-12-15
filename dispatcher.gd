extends Node

#region EXPORTS
@export_group('Settings')
@export_range(1, 1000) var _UPDATE_FREQUENCY : int = 60 ##Number of times per second
@export var AUTO_START : bool = false ##Start once scene starts
@export var DATA_TEXTURE : Texture2D ##Input data (expected as binary as in 1 for alive, 0 for dead)


@export_group('Requirements')
@export_file('*.glsl') var COMPUTE_SHADER_FILE : String
@export var _renderer : Sprite2D
#endregion

#region CONSTS
# these consts should match shader values to account for all pixels
const IMAGE_SIZE_PX = 1024
const NUM_COMPUTE_X_BLOCKS = 32
const NUM_COMPUTE_Y_BLOCKS = 32
const NUM_COMPUTE_Z_BLOCKS = 1
#endregion

#region INTERNALS
var _rd : RenderingDevice

var _input_texture : RID
var _output_texture : RID
var _uniform_set : RID
var _shader : RID
var _pipeline : RID

var _bindings : Array

var _input_image : Image
var _output_image : Image
var _render_texture : ImageTexture

var _input_format : RDTextureFormat
var _output_format : RDTextureFormat

var _is_processing : bool
var _process_timer : Timer
#endregion


#region MAIN LOOP
func _init() -> void:
	_process_timer = Timer.new()
	add_child(_process_timer)

func _ready() -> void:
	_init_images()
	_init_compute_shader()
	
	if AUTO_START == false: return
	start_process_loop()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed('toggle_processing'):
		if _is_processing:
			_is_processing = false
		else:
			start_process_loop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup_gpu()

#endregion


#region IMAGE SETUP
func merge_images() -> void:
	var output_width : int = _output_image.get_width()
	var output_height : int = _output_image.get_height()
	var input_width : int = _input_image.get_width()
	var input_height : int = _input_image.get_height()

	# calculate starting position of merging operation
	var start_x : int = int((output_width - input_width) / 2.0)
	var start_y : int = int((output_height - input_height) / 2.0)

	# merge from input to output
	for x in range(input_width):
		for y in range(input_height):
			var input_color : Color = _input_image.get_pixel(x, y)
			var dest_x = start_x + x
			var dest_y = start_y + y
			
			if (dest_x >= 0 && dest_x < output_width && dest_y >= 0 && dest_y < output_height ):
				_output_image.set_pixel(dest_x, dest_y, input_color)

	_input_image.set_data(
		IMAGE_SIZE_PX,
		IMAGE_SIZE_PX,
		false,
		Image.FORMAT_L8,
		_output_image.get_data()
	)

func link_output_texture_to_renderer_shader_material():
	var new_material : ShaderMaterial = _renderer.material as ShaderMaterial
	_render_texture = ImageTexture.create_from_image(_output_image)

	if new_material != null:
		new_material.set_shader_parameter('binaryDataTexture', _render_texture)
	else:
		print_debug('cannot find material on renderer')

func _init_images() -> void:
	_output_image = Image.create(IMAGE_SIZE_PX, IMAGE_SIZE_PX, false, Image.FORMAT_L8)

	if is_instance_valid(DATA_TEXTURE) == false:
		var noise : FastNoiseLite = FastNoiseLite.new()
		noise.frequency = 0.1
		var noise_image = noise.get_image(IMAGE_SIZE_PX, IMAGE_SIZE_PX)
		_input_image = noise_image
	else:
		_input_image = DATA_TEXTURE.get_image()

	merge_images()
	link_output_texture_to_renderer_shader_material()

#endregion


#region SHADER SETUP
func init_rendering_device() -> void:
	_rd = RenderingServer.create_local_rendering_device()

func init_shader() -> void:
	var shader_file : RDShaderFile = load(COMPUTE_SHADER_FILE)
	var spirv = shader_file.get_spirv()
	_shader = _rd.shader_create_from_spirv(spirv)

func init_pipeline() -> void:
	# requires shader to be initialized on the RD first
	_pipeline = _rd.compute_pipeline_create(_shader)

func get_default_texture_format() -> RDTextureFormat:
	var new_format : RDTextureFormat = RDTextureFormat.new()
	new_format.width = IMAGE_SIZE_PX
	new_format.height = IMAGE_SIZE_PX
	new_format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	new_format.usage_bits = \
		RenderingDevice.TextureUsageBits.TEXTURE_USAGE_STORAGE_BIT | \
		RenderingDevice.TextureUsageBits.TEXTURE_USAGE_CAN_UPDATE_BIT | \
		RenderingDevice.TextureUsageBits.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	return new_format

func init_texture_formats() -> void:
	_input_format = get_default_texture_format()
	_output_format = get_default_texture_format()

func create_texture_and_uniform(p_image : Image, p_format : RDTextureFormat, p_binding : int) -> RID:
	var view : RDTextureView = RDTextureView.new()
	var data : PackedByteArray = PackedByteArray()
	data = p_image.get_data()
	var texture_rid : RID = _rd.texture_create(p_format, view, [data])

	var uniform : RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = p_binding

	uniform.add_id(texture_rid)
	_bindings.append(uniform)

	return texture_rid


func init_uniforms() -> void:
	_input_texture = create_texture_and_uniform(_input_image, _input_format, 0) # should match binding from shader layout
	_output_texture = create_texture_and_uniform(_output_image, _output_format, 1) # should match binding from shader layout

	_uniform_set = _rd.uniform_set_create(_bindings, _shader, 0) # set should match shader layout


func _init_compute_shader() -> void:
	_bindings = []
	init_rendering_device()
	init_shader()
	init_pipeline()
	init_texture_formats()
	init_uniforms()

#endregion


#region PROCESSING
func start_process_loop() -> void:
	_is_processing = true
	
	_process_timer.start()
	
	while _is_processing == true:
		_process_timer.wait_time = 1.0 / float(_UPDATE_FREQUENCY)
		_update()
		await _process_timer.timeout
		_render()


func _update() -> void:
	# set up compute list
	var compute_list = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, _uniform_set, 0) # should match shader layout
	_rd.compute_list_dispatch(compute_list, NUM_COMPUTE_X_BLOCKS, NUM_COMPUTE_Y_BLOCKS, NUM_COMPUTE_Z_BLOCKS)
	_rd.compute_list_end()
	
	# submit here, sync in render
	_rd.submit()
	
func _render() -> void:
	# submit called in _update, sync here
	_rd.sync()
	
	# read and swap
	var bytes : PackedByteArray = _rd.texture_get_data(_output_texture, 0)
	_rd.texture_update(_input_texture, 0 , bytes)
	_output_image.set_data(IMAGE_SIZE_PX, IMAGE_SIZE_PX, false, Image.FORMAT_L8, bytes)
	_render_texture.update(_output_image)
	

func _cleanup_gpu() -> void:
	if _rd == null: return

	# All resources must be freed after use to avoid memory leaks.
	_rd.free_rid(_input_texture)
	_input_texture = RID()

	_rd.free_rid(_output_texture)
	_output_texture = RID()

	_rd.free_rid(_uniform_set)
	_uniform_set = RID()
	
	_rd.free_rid(_shader)
	_shader = RID()

	_rd.free_rid(_pipeline)
	_pipeline = RID()

	_rd.free()
	_rd = null
#endregion
