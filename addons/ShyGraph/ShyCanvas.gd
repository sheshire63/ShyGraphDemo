tool
extends Control


class_name ShyCanvas


signal saved(_data)
signal transform_changed


export var grid_step := 128

var transform := Transform2D.IDENTITY setget _set_offset
func _set_offset(new) -> void:
	transform = new
	_on_transform_changed()
	update()
	emit_signal("transform_changed")
var offset_rect := get_rect() #todo
var is_editor := true setget _set_is_editor
func _set_is_editor(new) -> void:
	is_editor = new


# virtual


func _select_area(_area: Rect2) -> void:
	pass


func _reset() -> void:
	pass


func _update() -> void:
	pass

func _on_transform_changed() -> void:
	pass

# flow


func _init(_is_editor := false) -> void: #is_editor = false if we want to use it in the editor
	_check_is_editor(_is_editor)


func _draw() -> void:
	_draw_grid()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			BUTTON_WHEEL_UP:
				scale(0.909091)
			BUTTON_WHEEL_DOWN:
				scale(1.1)
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(BUTTON_MIDDLE):
			move(-event.relative)


# puplic

func reset() -> void:
	self.transform = Transform2D.IDENTITY
	_reset()
	update()


func move(amount: Vector2) -> void:
	self.transform = transform.translated(amount)


func move_to(pos: Vector2) -> void:
	self.transform.origin = pos


func scale(amount: float) -> void:
	scale_to(transform.get_scale().x * amount)


func scale_to(scale: float) -> void:
	var mouse_from = position_to_offset(get_local_mouse_position())
	var new = Transform2D.IDENTITY.scaled(Vector2.ONE * scale)
	new.origin = transform.origin
	transform = new
	var mouse_to = position_to_offset(get_local_mouse_position())
	transform.origin += mouse_from - mouse_to
	self.transform = transform


func offset_to_position(offset: Vector2) -> Vector2:
	return transform.affine_inverse().xform(offset)


func position_to_offset(position: Vector2) -> Vector2:
	return transform.xform(position)


# private


func _check_is_editor(_is_editor: bool) -> void:
	if Engine.editor_hint:
		is_editor = _is_editor
	else:
		is_editor = false


func _draw_grid() -> void:
	var from = position_to_offset(Vector2.ZERO)
	var to = position_to_offset(rect_size)
	var x = stepify(from.x, grid_step)
	var test = Vector2(128, 128)
	while x < to.x:
		var pos = offset_to_position(Vector2.ONE * x)
		draw_line(Vector2(pos.x, 0), Vector2(pos.x, rect_size.y), Color.gray)
		x += grid_step
	var y = stepify(from.y, grid_step)
	while y < to.y:
		var pos = offset_to_position(Vector2.ONE * y)
		draw_line(Vector2(0, pos.y), Vector2(rect_size.x, pos.y), Color.gray)
		y += grid_step