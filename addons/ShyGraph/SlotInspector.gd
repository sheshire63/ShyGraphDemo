tool
extends EditorInspectorPlugin

class_name SlotInspectorPlugin


const InspectorControl = preload("res://addons/ShyGraph/SlotInspector.tscn")


func can_handle(object: Object) -> bool:
	return object is ShyGraphNode


func parse_begin(object: Object) -> void:
	var control = InspectorControl.instance()
	control.node = object
	add_custom_control(control)



#todo:
# add hide option?