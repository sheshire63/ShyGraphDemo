tool
extends EditorInspectorPlugin

class_name TypeInspectorPlugin


const InspectorControl = preload("res://addons/ShyGraph/TypeInspector.tscn")


func can_handle(object: Object) -> bool:
	return object is ShyGraphEdit


func parse_begin(object: Object) -> void:
	var control = InspectorControl.instance()
	control.edit = object
	add_custom_control(control)



#todo:
# add hide option?