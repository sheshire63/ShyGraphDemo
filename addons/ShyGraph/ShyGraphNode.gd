tool
extends Control

class_name ShyGraphNode

signal offset_changed(new_offset)
signal moved(amount)
signal moved_to(new_offset)
signal slot_added(slot, id)
signal slot_changed(slot, id)
signal slot_removed(slot, id)
signal selected
signal deselected
signal delete

signal _request_select()


enum ALLIGN {BEGIN, CENTER, END}
enum SIDE {LEFT, RIGHT, TOP, BOTTOM}


var offset := Vector2.ZERO setget _set_offset; func _set_offset(new):
		offset = new
		_update_position()
		emit_signal("offset_changed", offset)
var slots := [] setget _set_slots
func _set_slots(new) -> void:
	_clear_slots()
	slots = new
	_setup_slots()
var type: String
var selected := false setget _set_selected

var _slot_controls := {}
var _is_moving := false
var _moved_from: Vector2

#theme
var _background: StyleBox
var _bg_selected: StyleBox


# flow

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
	if get_parent().has_signal("transform_changed"):
		get_parent().connect("transform_changed", self, "_on_parent_transform_changed")
	self.offset = offset
	_update_theme()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(BUTTON_LEFT):
			_move(event.relative)
	if event is InputEventMouseButton:
		match event.button_index:
			BUTTON_LEFT:
				if event.pressed:
					if !selected or Input.is_key_pressed(KEY_CONTROL):
						emit_signal("_request_select", self)
				else:
					_end_move()


func _draw() -> void:
	#draw_string(get_font("font", ""), Vector2.ZERO, name)
	if selected:
		draw_style_box(_bg_selected , Rect2(Vector2.ZERO, rect_size))
	else:
		draw_style_box(_background, Rect2(Vector2.ZERO, rect_size))



# public

func save_data() -> Dictionary:
	return {
		"type": type,
		"offset": offset,
		"data": _save_data(),
	}


func load_data(data:= {}) -> void:
	if "offset" in data:
		self.offset = data["offset"]
	if "type" in data:
		self.type = data["type"]
	if "data" in data:
		_load_data(data.data)


func select() -> void:
	if Input.is_key_pressed(KEY_CONTROL) and selected:
			deselect()
			return
	self.selected = true
	emit_signal("selected")


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


func new_slot(active := true, offset := Vector2.ZERO, size := Vector2.ONE, anchor := "", type := 0, allign := 1, side := 0) -> Dictionary:
	print("mew")
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
	_add_slot_control(slot, slots.size() - 1)
	emit_signal("slot_added", slot, slots.size() - 1)


func remove_slot(slot:= 0) -> void:
	if slot < 0 or slot >= slots.size():
		return
	var old = slots[slot]
	slots.remove(slot)
	_remove_slot_control(slot)
	emit_signal("slot_removed", old)


func get_slot_offset(slot_index: int) -> Vector2:
	return _get_slot_offset(slots[slot_index]) + offset


func update_slot(slot: Dictionary) -> void:
	var index = slots.find(slot)
	if index in _slot_controls:#slot gets checked as value not as reference or the slot in button is not the same
		_slot_controls[index].update_position()
		update()


func get_slot(id: int) -> Dictionary:
	if slots.size() > id:
		return slots[id]
	return {}


func set_slot_enabled(slot: int, enabled: bool) -> void:
	slots[slot].active = enabled
	update()


func set_slot_offset(slot: int, offset: Vector2) -> void:
	slots[slot].offset = offset
	update()

func set_slot_size(slot: int, size: Vector2) -> void:
	slots[slot].size = size
	update()


func set_slot_anchor(slot: int, node: NodePath) -> void:
	slots[slot].anchor = node
	update()


func set_slot_type(slot: int, type: int) -> void:
	slots[slot].type = type
	update()


func set_slot_allign(slot: int, allign: int) -> void:
	slots[slot].allign = allign
	update()


func set_slot_side(slot: int, side: int) -> void:
	slots[slot].side = side
	update()


#virtual----------------------------------------------------


func _save_data() -> Dictionary:
	return {}


func _load_data(data:= {}) -> void:
	pass


func _delete() -> void:
	pass


func _copy(copy) -> void:#if you need to set somthing in the copy.
	pass


# private funcs----------------------------------------------------


func _set_selected(new: bool) -> void:
	selected = new
	update()
	# if selected:
	# 	if select_theme:
	# 		theme = select_theme
	# 	else:
	# 		modulate  = Color(1.1, 1.1, 1.1)
	# else:
	# 	if select_theme:
	# 		theme = default_theme
	# 	else:
	# 		modulate = Color(1, 1, 1)


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


func _update_theme() -> void:
	if has_stylebox("background", ""):
		_background = get_stylebox("background", "")
	else:
		_background = StyleBoxFlat.new()
		_background.bg_color = Color(0.2,0.2,0.2)
	if has_stylebox("background_selected", ""):
		_bg_selected = get_stylebox("background_selected", "")
	else:
		_bg_selected = StyleBoxFlat.new()
		_bg_selected.bg_color = Color(0.3,0.3,0.3)


func _clear_slots() -> void:
	for i in _slot_controls:
		remove_child(_slot_controls[i])
		_slot_controls[i].queue_free()
	_slot_controls = {}
	slots = []
	for i in get_children():
		if i is SlotButton:
			i.queue_free()


func _setup_slots() -> void:
	for i in slots.size():
		if !slots[i]:
			print("new")
			slots[i] = new_slot()
			print(slots[i])
		_add_slot_control(slots[i], i)


func _update_position() -> void:
	var new: Vector2
	if get_parent() and get_parent().has_method("offset_to_position"):
		new = get_parent().offset_to_position(offset)
	else:
		new = offset
	rect_position = new


func _update_slots() -> void:
	for i in _slot_controls:
		_slot_controls[i].update()


func _end_move() -> void:
	if _is_moving:
		_is_moving = false
		emit_signal("moved_to", offset, _moved_from)


func _move(amount:Vector2) -> void:
	if !_is_moving:
		_is_moving = true
		_moved_from = offset
	self.offset += amount
	emit_signal("moved", amount)


func _on_parent_transform_changed(transform: Transform2D) -> void:
	_update_position()
	rect_scale = Vector2.ONE / transform.get_scale()


func _add_slot_control(slot: Dictionary, index: int) -> SlotButton:
	var control = SlotButton.new(index)
	add_child(control)
	control.slot = slot
	_slot_controls[slots.find(slot)] = control
	return control


func _remove_slot_control(slot: int) -> void:
	remove_child(_slot_controls[slot])
	_slot_controls[slot].queue_free()
	_slot_controls.erase(slot)