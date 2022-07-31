tool
extends EditorPlugin


var control = preload("res://addons/Test/DemoEditor.tscn").instance()


func _enter_tree() -> void:
    add_control_to_bottom_panel(control, "Demo")
    control.set_edit()


func _exit_tree() -> void:
	remove_control_from_bottom_panel(control)
	control.queue_free()


func handles(object: Object) -> bool:
    return object is EditorGraph

func edit(object: Object) -> void:
    control.set_graph(object)

