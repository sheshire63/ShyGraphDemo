tool
extends Panel

class_name ShyGraphNode

signal offset_changed(from, to)
signal moved(amount)
signal slot_added(slot, id)
signal slot_removed(slot)
signal selected(multiple)
signal deselected
signal request_deselect
signal delete


enum ALLIGN {BEGIN, CENTER, END}
enum SIDE {LEFT, RIGHT, TOP, BOTTOM}


var offset := Vector2.ZERO setget _set_offset
func _set_offset(new):
	var old := offset
	offset = new
	update_position()
	emit_signal("offset_changed", old, new)
var slots := []
var slot_controls := {}
var type: String
var selected := false setget _set_selected
var default_theme: Theme
export var select_theme: Theme


#virtual----------------------------------------------------


func _save_data() -> Dictionary:
	return {}


func _load_data(data:= {}) -> void:
	pass


func _delete() -> void:
	pass


func _copy(copy) -> void:#if you need to set somthing in the copy.
	pass


#behavior----------------------------------------------------


func _get_property_list() -> Array:
	return [
		{
			"name": "slots",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_STORAGE,
			"hint_string": "Slot",
		}
	]


func _init() -> void:
	rect_min_size = Vector2(max(64, rect_min_size.x), max(64, rect_min_size.y))
	

func _ready() -> void:
	for i in slots.size():
		add_slot_control(slots[i])
	default_theme = theme
	move(Vector2.ZERO)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(BUTTON_LEFT):
			move(event.relative)
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				select()


#functions----------------------------------------------------


func move(amount:Vector2) -> void:
	self.offset += amount
	emit_signal("moved", amount)


func update_position() -> void:
	if get_parent().has_method("offset_to_position"):
		rect_position = get_parent().offset_to_position(offset)
	else:
		rect_position = offset


func save_data() -> Dictionary:
	return {
		"type": type,
		"slots": slots,
		"offset": offset,
		"data": _save_data(),
	}


func load_data(data:= {}) -> void:
	if "offset" in data:
		offset = data["offset"]
	if "slots" in data:
		slots = data["slots"]
	if "data" in data:
		_load_data(data.data)


func select() -> void:
	if Input.is_key_pressed(KEY_CONTROL):
		if selected:
			self.selected = false
			emit_signal("deselected")
		else: 
			self.selected = true
			emit_signal("selected", true)
	elif !selected:
		emit_signal("request_deselect")
		self.selected = true
		emit_signal("selected", false)


func deselect() -> void:
	self. selected = false
	emit_signal("deselected")


func copy():
	var copy = self.duplicate()
	_copy(copy)
	return copy


func delete() -> void:
	_delete()
	emit_signal("delete")
	self.queue_free()


#slot functions----------------------------------------------------


func add_slot(active := true, offset := Vector2.ZERO, size := Vector2.ONE, anchor := -1, type := 0, allign := 0, side := 0) -> void:
	var slot = {
		"active": active,
		"offset": offset,
		"size": size,
		"anchor": anchor,
		"type": type,
		"allign": allign,
		"side": side,
	}
	slots.append(slot)
	add_slot_control(slot)
	emit_signal("slot_added", slot, slots.size() - 1)


func remove_slot(slot:= 0) -> void:
	if slot < 0 or slot >= slots.size():
		return
	var old = slots[slot]
	slots.remove(slot)
	remove_slot_control(slot)
	emit_signal("slot_removed", old)


func set_slot_count(count: int) -> void:
	while slots.size() < count:
		add_slot()
	while slots.size() > count:
		var slot = slots.pop_back()
		slot_controls[slots.size()].queue_free()
		slot_controls.erase(slots.size())
		

func get_slot_offset(slot_index: int) -> Vector2:
	return _get_slot_offset(slots[slot_index]) + offset


func add_slot_control(slot: Dictionary) -> SlotButton:
	var control = SlotButton.new()
	add_child(control)
	control.slot = slot
	slot_controls[slots.find(slot)] = control
	return control


func remove_slot_control(slot: int) -> void:
	slot_controls[slot].queue_free()
	slot_controls.erase(slot)


func update_slot(slot: Dictionary) -> void:
	var index = slots.find(slot)
	if index in slot_controls:#slot gets checked as value not as reference or the slot in button is not the same
		slot_controls[index].update_position()
		update()


func get_slot(id: int) -> Dictionary:
	if slots.size() > id:
		return slots[id]
	return {}


#internal funcs----------------------------------------------------


func _set_selected(new: bool) -> void:
	selected = new
	if selected:
		if select_theme:
			theme = select_theme
		else:
			modulate  = Color(1.1, 1.1, 1.1)
	else:
		if select_theme:
			theme = default_theme
		else:
			modulate = Color(1, 1, 1)


func _get_slot_offset(slot: Dictionary) -> Vector2:
	var anchor_rect: Rect2
	if slot.anchor >= 0 and get_child_count() < slot.anchor:
		anchor_rect = get_child(slot.anchor).get_rect()
	else:
		anchor_rect = get_rect()
		anchor_rect.position = Vector2.ZERO
	var res = Vector2.ZERO
	match slot.allign:
		ALLIGN.BEGIN:
			res = anchor_rect.position
		ALLIGN.CENTER:
			res = anchor_rect.position + anchor_rect.size / 2
		ALLIGN.END:
			res = anchor_rect.end
	match slot.side:
		SIDE.LEFT:
			res.x = 0
		SIDE.RIGHT:
			res.x = rect_size.x
		SIDE.TOP:
			res.y = 0
		SIDE.BOTTOM:
			res.y = rect_size.y
	return res + slot.offset
