tool
extends Panel

onready var c_box := $Controls

onready var c_name := $Controls/Name
onready var c_color := $Controls/Color
onready var c_size_x := $Controls/Size/X
onready var c_size_y := $Controls/Size/Y
onready var c_multiple := $Controls/Multiple
onready var c_sides := $Controls/Sides

onready var c_index := $Index



var type : Dictionary setget _set_type
func _set_type(new):
	type = new
	if !is_inside_tree() or !new:
		return
	c_name.text = new.name
	c_color.color = new.color
	c_size_x.value = new.size.x
	c_size_y.value = new.size.y
	c_multiple.pressed = new.multiple
	c_sides.matrix = new.connections
	_setup_side()


var edit : ShyGraphEdit setget _set_edit
func _set_edit(new):
	edit = new
	if !is_inside_tree() or !new:
		return
	c_index.value = edit.types.find(type)


func _ready() -> void:
	_set_edit(edit)
	_set_type(type)
	_setup_side()


func _on_Name_text_changed(new_text:String) -> void:
	type.name = new_text
	edit.update()


func _on_Color_color_changed(color:Color) -> void:
	type.color = color
	edit.update()


func _on_X_value_changed(value:float) -> void:
	type.size.x = value
	edit.update()
	

func _on_Y_value_changed(value:float) -> void:
	type.size.y = value
	edit.update()


func _on_Multiple_toggled(button_pressed:bool) -> void:
	type.multiple = button_pressed


func _setup_side() -> void:
	if !edit:
		return
	c_sides.names_x = ShyGraphNode.SIDE.keys()
	var list = []
	for i in edit.types:
		list.append(str(i.name))
	c_sides.names_y = list
	c_box.rect_size = Vector2.ZERO
	_update_size()


func _update_size() -> void:
	rect_min_size = Vector2.RIGHT * 74 + c_box.rect_size
	rect_size = Vector2.ZERO