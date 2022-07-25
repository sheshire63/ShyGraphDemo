tool
extends Control


onready var count = $HBoxContainer/Count

const TypeControl = preload("res://addons/ShyGraph/TypeControl.tscn")

var edit : ShyGraphEdit setget _set_edit

var _set_on_ready := false

func _set_edit(new) -> void:
	edit = new
	if new:
		if !is_inside_tree():
			_set_on_ready = true
			return
		count.value = new.types.size()
		clear()
		for type in edit.types:
			add_type(type)
		_set_on_ready = false


func clear() -> void:
	for i in get_children():
		if i is Panel:
			i.queue_free()


func add_type(type) -> void:
	var new_control := TypeControl.instance()
	new_control.type = type
	new_control.edit = edit
	add_child(new_control)


func _on_Count_value_changed(value: float) -> void:
	edit.set_type_count(value)
	_set_edit(edit)


func _ready() -> void:
	if _set_on_ready:
		_set_edit(edit)
		
