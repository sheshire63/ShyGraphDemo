tool
extends EditorPlugin


const node_folder_setting := "ShyGraph/node_folder_path"
var slot_inspector := SlotInspectorPlugin.new()
var type_inspector := TypeInspectorPlugin.new()


func enable_plugin() -> void:
	var input = InputEventKey.new()
	input.scancode = KEY_CONTROL
	ProjectSettings.set_setting("input/" + ShyGraphEdit.break_line_key, 
		{
			"deadzone": 0.5,
			"events": [input],
		})
	ProjectSettings.save()
	# create_node_folder()


func disable_plugin() -> void:
	ProjectSettings.set_setting("input/" + ShyGraphEdit.break_line_key, null)
	# ProjectSettings.set_setting(node_folder_setting, null)


func _enter_tree() -> void:
	# slot_inspector.connect("changed", self, "_slot_inspector_changed")
	add_inspector_plugin(slot_inspector)
	add_inspector_plugin(type_inspector)
	# ProjectSettings.set_setting(node_folder_setting, "res://Nodes")


func _exit_tree() -> void:
	remove_inspector_plugin(slot_inspector)
	remove_inspector_plugin(type_inspector)


func _slot_inspector_changed(_sender) -> void:
	get_editor_interface().inspect_object(_sender)



# func create_node_folder() -> void:
# 	var dir = Directory.new()
# 	var path = ProjectSettings.get_setting(node_folder_setting)
# 	if !dir.dir_exists(path):
# 		dir.make_dir_recursive(path)