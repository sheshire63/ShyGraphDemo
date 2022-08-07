tool
extends Panel

class_name ShyGraphNode

signal offset_changed(new_offset)
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
	offset = new
	update_position()
	
var slots := [] setget _set_slots
func _set_slots(new) -> void:
	clear()
	slots = new
	setup()
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
	var list := [
		{
			"name": "Slots",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_CATEGORY,
		},
		{
			"name": "slots",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint_string": "Slot",
		}]
	return list


func _init() -> void:
	rect_min_size = Vector2(max(64, rect_min_size.x), max(64, rect_min_size.y))
	

func _ready() -> void:
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


func clear() -> void:
	for i in slot_controls:
		remove_child(slot_controls[i])
		slot_controls[i].queue_free()
	slot_controls = {}
	slots = []


func setup() -> void:
	for i in slots.size():
		if !slots[i]:
			slots[i] = new_slot()
		add_slot_control(slots[i], i)


func move(amount:Vector2) -> void:
	self.offset += amount
	emit_signal("moved", amount)


func update_position() -> void:
	var new: Vector2
	if get_parent().has_method("offset_to_position"):
		new = get_parent().offset_to_position(offset)
	else:
		new = offset
	if rect_position != new:
		rect_position = new
		emit_signal("offset_changed", offset)
	for i in slot_controls:
		slot_controls[i].update()


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
	if "type" in data:
		type = data["type"]
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


func new_slot(active := true, offset := Vector2.ZERO, size := Vector2.ONE, anchor := "", type := 0, allign := 0, side := 0) -> Dictionary:
	return {
		"active": active,
		"offset": offset,
		"size": size,
		"anchor": anchor,
		"type": type,
		"allign": allign,
		"side": side,
	}
	

func add_slot(slot := {}) -> void:
	if !slot:
		slot = new_slot()
	slots.append(slot)
	add_slot_control(slot, slots.size() - 1)
	emit_signal("slot_added", slot, slots.size() - 1)


func remove_slot(slot:= 0) -> void:
	if slot < 0 or slot >= slots.size():
		return
	var old = slots[slot]
	slots.remove(slot)
	remove_slot_control(slot)
	emit_signal("slot_removed", old)


func get_slot_offset(slot_index: int) -> Vector2:
	return _get_slot_offset(slots[slot_index]) + offset


func add_slot_control(slot: Dictionary, index: int) -> SlotButton:
	var control = SlotButton.new(index)
	add_child(control)
	control.slot = slot
	slot_controls[slots.find(slot)] = control
	return control


func remove_slot_control(slot: int) -> void:
	remove_child(slot_controls[slot])
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
	var anchor_rect
	if slot.anchor:
		if has_node(slot.anchor):
			var anchor_node = get_node(slot.anchor)
			if not anchor_node is Control:
				printerr("node `%S` is not a Control"%[slot.anchor])
			anchor_rect = anchor_node.get_rect()
			var parent = anchor_node.get_parent()
			while parent != self:
				anchor_rect.position += parent.rect_position
				parent = parent.get_parent()
		else:
			printerr("node `%S` not found"%[slot.anchor])
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


