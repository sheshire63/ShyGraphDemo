tool
extends Panel


onready var c_active := $Controls/Active
onready var c_type := $Controls/Type
onready var c_side := $Controls/Side
onready var c_allign := $Controls/Allign
onready var c_offset_x := $Controls/Offset/OffsetX
onready var c_offset_y := $Controls/Offset/OffsetY
onready var c_anchor := $Controls/Child
onready var c_size_x := $Controls/Size/SizeX
onready var c_size_y := $Controls/Size/SizeY

onready var c_index := $Index

var slot : Dictionary setget _set_slot
func _set_slot(new):
	slot = new
	if !is_inside_tree():
		return
	c_active.pressed = slot.active
	c_type.selected = slot.type
	c_side.selected = slot.side
	c_allign.selected = slot.allign
	c_offset_x.value = slot.offset.x
	c_offset_y.value = slot.offset.y
	c_anchor.selected = slot.anchor + 1
	c_size_x.value = slot.size.x
	c_size_y.value = slot.size.y

var node : ShyGraphNode setget _set_node
func _set_node(new):
	node = new
	if !is_inside_tree():
		return
	c_index.value = node.slots.find(slot)


func _ready() -> void:	
	var editor: ShyGraphEdit = node.get_parent()
	if editor:
		for i in editor.types:
			c_type.add_item(i.name)
	for i in node.ALLIGN:
		c_allign.add_item(i)
	for i in node.SIDE:
		c_side.add_item(i)
	c_anchor.add_item("None")
	for i in node.get_children():
		c_anchor.add_item(i.name)
	_set_slot(slot)
	c_active.connect("toggled", self, "_on_active_toggled")
	c_type.connect("item_selected", self, "_on_type_item_selected")
	c_side.connect("item_selected", self, "_on_side_item_selected")
	c_allign.connect("item_selected", self, "_on_allign_item_selected")
	c_offset_x.connect("value_changed", self, "_on_offset_x_value_changed")
	c_offset_y.connect("value_changed", self, "_on_offset_y_value_changed")
	c_anchor.connect("item_selected", self, "_on_anchor_item_selected")
	c_size_x.connect("value_changed", self, "_on_size_x_value_changed")
	c_size_y.connect("value_changed", self, "_on_size_y_value_changed")


func _on_Index_value_changed(value:float) -> void:
	var node = slot.node
	node.slots.erase(slot)
	node.slots.insert(value, slot)


func _on_active_toggled(button_pressed:bool) -> void:
	slot.active = button_pressed
	updata_slot()


func _on_type_item_selected(index:int) -> void:
	slot.type = index
	updata_slot()


func _on_side_item_selected(index:int) -> void:
	slot.side = index
	updata_slot()


func _on_allign_item_selected(index:int) -> void:
	slot.allign = index
	updata_slot()


func _on_offset_x_value_changed(value:float) -> void:
	slot.offset.x = value
	updata_slot()


func _on_offset_y_value_changed(value:float) -> void:
	slot.offset.y = value
	updata_slot()


func _on_size_x_value_changed(value:float) -> void:
	slot.size.x = value
	updata_slot()


func _on_size_y_value_changed(value:float) -> void:
	slot.size.y = value
	updata_slot()


func _on_anchor_item_selected(index:int) -> void:
	slot.anchor = index - 1
	updata_slot()


func updata_slot() -> void:
	node.update_slot(slot)
