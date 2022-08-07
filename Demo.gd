
extends Control


export var graph_file := "res://Graph.dat"
onready var editor := $ShyGraphEdit


func _ready() -> void:
	var file = File.new()
	if file.file_exists(graph_file):
		file.open(graph_file, File.READ)
		editor.load_data(str2var(file.get_as_text()))
		file.close()


func _exit_tree() -> void:
	if graph_file:
		var file = File.new()
		file.open(graph_file, File.WRITE)
		file.store_string(var2str(editor.save_data()))
		file.close()
