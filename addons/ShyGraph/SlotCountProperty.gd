tool
extends EditorProperty

class_name SlotCounter


var control := SpinBox.new()
var updating := false


func _init() -> void:
	label = "Slot Count"
	add_child(control)
	add_focusable(control)
	control.connect("value_changed", self, "_on_value_changed")


func _on_value_changed(new: float) -> void:
	if updating:
		return
	get_edited_object().set_slot_count(new)
	emit_changed("slots", get_edited_object().slots, "", true)


func update_property() -> void:
	if get_edited_object():
		control.value = get_edited_object().slots.size()