tool
extends Control


onready var editor := $ShyGraphEdit


# func set_edit() -> void:
# 	editor.is_editor = false	


func set_graph(data: EditorGraph) -> void:
	editor.load_data = data.data


