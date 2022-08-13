tool
extends Control


class_name ShyCanvas


signal saved(_data)
signal transform_changed


export var grid_step := 128

var transform := Transform2D.IDENTITY setget _set_offset
func _set_offset(new) -> void:
	transform =_limit_transform_to_rect(new)
	_on_transform_changed()
	update()
	emit_signal("transform_changed")
var area_rect := get_rect() #todo
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


func _ready() -> void:
	call_deferred("reset")


func _draw() -> void:
	_draw_grid()
	draw_rect(offset_to_position(area_rect), Color.green, false, 5.0)
	draw_circle(rect_size / 2, 5.0, Color.aquamarine)


func _process(delta: float) -> void:
	update()


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
	area_rect = get_rect()
	update_rect()
	_reset()
	update()


func update_rect() -> void:
	var rect = Rect2(offset_to_position(Vector2.ZERO), Vector2.ZERO)


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


func offset_to_position(value, translate := true):
	if translate:
		return transform.affine_inverse().xform(value)
	else:
		return transform.affine_inverse().basis_xform(value)


func position_to_offset(value, translate := true):
	if translate:
		return transform.xform(value)
	else:
		return transform.basis_xform(value)


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


func _limit_transform_to_rect(value: Transform2D) -> Transform2D:#todo its offcenter
	var offset = position_to_offset(rect_size / 2, false)
	value.origin = _get_nearest_point_in_rect(value.origin + offset, area_rect) - offset
	return value


func _get_nearest_point_in_rect(point: Vector2, rect: Rect2) -> Vector2:
	if rect.has_point(point):
		return point
	point.x = max(rect.position.x, min(point.x, rect.end.x))
	point.y = max(rect.position.y, min(point.y, rect.end.y))
	return point