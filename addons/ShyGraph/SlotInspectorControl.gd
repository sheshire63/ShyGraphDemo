tool
extends Control


onready var count = $HBoxContainer/Count

const SlotControl = preload("res://addons/ShyGraph/SlotControl.tscn")

var node : ShyGraphNode setget _set_node


func _set_node(new) -> void:
	node = new
	if !is_inside_tree():
		return
	count.value = new.slots.size()
	clear()
	for slot in node.slots:
		add_slot(slot)


func clear() -> void:
	for i in get_children():
		if i is Panel:
			i.queue_free()


func add_slot(slot) -> void:
	var new_control := SlotControl.instance()
	new_control.slot = slot
	new_control.node = node
	add_child(new_control)


func _on_Count_value_changed(value: float) -> void:
	node.set_slot_count(value)
	_set_node(node)


func _ready() -> void:
	_set_node(node)
