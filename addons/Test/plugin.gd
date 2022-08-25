tool
extends EditorPlugin


var control = preload("res://addons/Test/DemoEditor.tscn").instance()
var object

func _enter_tree() -> void:
	add_control_to_bottom_panel(control, "Demo")
	# control.set_edit()


func _exit_tree() -> void:
	remove_control_from_bottom_panel(control)
	control.queue_free()


func handles(object: Object) -> bool:
	return object is EditorGraph


func edit(_object: Object) -> void:
	if object:
		object.data = control.editor.save_data()
	object = _object
	control.editor.load_data(object.data)



func save_external_data() -> void:
	if object:
		object.data = control.editor.save_data()
