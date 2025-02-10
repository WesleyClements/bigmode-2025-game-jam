extends Container


var active_camera: Camera2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(on_viewport_size_changed)

func _physics_process(_delta: float) -> void:
	var view_port := get_viewport()
	var camera := view_port.get_camera_2d()
	if camera == null:
		return
	if active_camera == camera:
		return
	active_camera = camera
	scale = camera.get_zoom() / 2.0
	set_deferred(&"size", calculate_size(view_port) / scale)

func get_project_viewport_size() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)

func calculate_size(view_port: Viewport) -> Vector2:
	var project_viewport_size := get_project_viewport_size()
	var view_port_size := Vector2(view_port.size)
	var x := project_viewport_size.x
	if view_port_size.x * project_viewport_size.y / project_viewport_size.x > view_port_size.y:
		x = project_viewport_size.y * view_port_size.x / view_port_size.y
	return Vector2(
		x,
		project_viewport_size.y
	)

func on_viewport_size_changed():
	var view_port := get_viewport()
	size = calculate_size(view_port) / scale