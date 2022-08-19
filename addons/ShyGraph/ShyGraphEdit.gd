tool 
extends ShyCanvas


class_name ShyGraphEdit


enum line_types {line, bezier}
const SIDES = {
		ShyGraphNode.SIDE.LEFT: Vector2.LEFT,
		ShyGraphNode.SIDE.RIGHT: Vector2.RIGHT,
		ShyGraphNode.SIDE.TOP: Vector2.UP,
		ShyGraphNode.SIDE.BOTTOM: Vector2.DOWN,
		}
# const break_line_key := "shy_graph_break_lines"


signal connected (from, to)
signal disconnected (from, to)
signal nodes_loaded
signal cleared
signal node_added (node)#not called on load
signal node_removed (node) #not called on clear
signal node_moved (node)
signal node_selected (node)
signal node_deselected (node)


onready var node_menu := $Nodes

export(String, DIR) var node_folder := ""
var types := [] setget _set_types; func _set_types(new) -> void:
		for i in new.size():
			if !new[i]:
				new[i] = new_type()
		types = new
		update_nodes()
export(line_types) var line_type := line_types.line

var nodes := {}
var connections := []
var create_connection_from := {}
var hover_slot := {}
var break_from: Vector2
var selected_nodes := []
var select_from : Vector2

#theme
var break_line_color := Color.red
var break_line_width := 1
var line_width := 5
var selection_fill_color := Color(0.5, 0.5, 0.5, 0.5)
var selection_stroke_color := Color.gray
var selection_stroke_width := 1.0


func _get_property_list() -> Array:
	var list := [
		{
			"name": "Types",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_CATEGORY,
		},
		{
			"name": "types",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint_string": "Types",
		},
	]
	return list


func _ready() -> void:
	if Engine.editor_hint:
		return
	_load_nodes()
	connect("transform_changed", self, "_on_transform_changed")


func _process(delta: float) -> void:
	if create_connection_from or break_from or select_from:
		update()


func _draw() -> void:
	var tf = transform.affine_inverse()
	draw_set_transform(tf.origin, tf.get_rotation(), tf.get_scale())
	_draw_connections()
	_draw_create_connection()
	if break_from:
		draw_line(break_from, position_to_offset(get_local_mouse_position()), break_line_color, break_line_width)
	if select_from:
		draw_rect(Rect2(select_from, position_to_offset(get_local_mouse_position()) - select_from), selection_fill_color)
		draw_rect(Rect2(select_from, position_to_offset(get_local_mouse_position()) - select_from), selection_stroke_color, false, selection_stroke_width)


func _input(event: InputEvent) -> void:
	if Engine.editor_hint:
		return
	if event is InputEventKey:
		match event.scancode:
			KEY_CONTROL:
				break_from = Vector2.ZERO
				update()
			KEY_DELETE:
				delete_selected()


func _gui_input(event: InputEvent) -> void:
	if Engine.editor_hint:
		return
	if event is InputEventMouseButton:
		if event.is_pressed():
			match event.button_index:
				BUTTON_LEFT:
					create_connection_from = {}
					if Input.is_key_pressed(KEY_CONTROL):
						break_from = position_to_offset(get_local_mouse_position())
					else:
						_start_select_drag()
					update()
				BUTTON_RIGHT:
					node_menu.popup(Rect2(event.global_position, node_menu.rect_size))
		else:
			if event.button_index == BUTTON_LEFT:
				if Input.is_key_pressed(KEY_CONTROL):
					_break_connections()
				_end_select_drag()


func _on_Nodes_id_pressed(id:int) -> void:
	var node =_create_node_instance(nodes.values()[id])
	node.type = nodes.keys()[id]
	node.offset = position_to_offset(get_local_mouse_position())
	emit_signal("node_added", node)

#node flow


func _on_node_moved(amount: Vector2, node: ShyGraphNode) -> void:
	var rect = area_rect
	rect = rect.expand(node.offset)
	rect = rect.expand(node.offset + node.rect_size)
	for i in selected_nodes:
		if i == node:
			continue
		i.offset += amount
		rect = rect.expand(i.offset)
		rect = rect.expand(i.offset + i.rect_size)
	update()
	emit_signal("node_moved", node)
	self.area_rect = rect


func _on_node_selected(multiple: bool, node: ShyGraphNode) -> void:
	if !multiple:
		deselect()
	selected_nodes.append(node)
	emit_signal("node_selected", node)


func _on_node_deselected(node: ShyGraphNode) -> void:
	selected_nodes.erase(node)
	emit_signal("node_deselected", node)


func _on_node_delete(node) -> void:
	var to_remove = []
	for i in connections:
		if i.from.node == node.name or i.to.node == node.name:
			to_remove.append(i)
	for i in to_remove:
		remove_connection(i)
	emit_signal("node_removed", node)


func _on_node_request_deselect() -> void:
	deselect()


# overrides


func _set_is_editor(new) -> void:
	._set_is_editor(new)
	if !new:
		_load_nodes()


func _on_transform_changed() -> void:
	update_nodes()


# global

func clear() -> void:
	connections = []
	create_connection_from = {}
	selected_nodes = []
	for i in get_children():
		if i is ShyGraphNode:
			i.queue_free()
	reset()
	emit_signal("cleared")


func deselect() -> void:
	for i in selected_nodes:
		i.selected = false
		_on_node_deselected(i)
	selected_nodes = []


func select(node: ShyGraphNode) -> void:
	if node in selected_nodes:
		return
	selected_nodes.append(node)
	node.selected = true


func select_multiple(nodes: Array) -> void:
	if !Input.is_key_pressed(KEY_CONTROL):
		deselect()
	for i in nodes:
		select(i)	


func init_drag(slot: Dictionary) -> void:
	if create_connection_from:
		_end_drag(slot)
	else:
		_start_drag(slot)


func save_data() -> Dictionary:
	var data = {"nodes": {}, "connections": connections}
	for child in get_children():
		if child is ShyGraphNode:
			data.nodes[child.name] = child.save_data()
	emit_signal("saved", data)
	return data


func load_data(data: Dictionary) -> void:
	clear()
	if data:
		connections = data.connections
		for i in data.nodes:
			var node_data = data.nodes[i]
			if node_data.type in nodes:
				var node = _create_node_instance(nodes[node_data.type], node_data)
				node.name = i
			else:
				printerr("node type not found: %s"%(node_data.type))
		

func add_connection(from: Dictionary, to: Dictionary) -> void:
	if !_is_connection_allowed(from, to):
		return
	var from_node: ShyGraphNode = get_node(from.node)
	var from_slot = from_node.get_slot(from.slot)
	var to_node: ShyGraphNode = get_node(to.node)
	var to_slot = to_node.get_slot(to.slot)
	if !types[from_slot.type].multiple:
		_disconnect_slot(from.node, from.slot)
	if !types[to_slot.type].multiple:
		_disconnect_slot(to.node, to.slot)
	connections.append({"from": from, "to": to})
	emit_signal("connected", from, to)


func remove_connection(connection: Dictionary) -> void:
	connections.erase(connection)
	update()
	emit_signal("disconnected", connection.from, connection.to)


func get_type_color(type: int) -> Color:
	if type < 0 or type >= types.size():
		printerr("Invalid type: " + str(type))
		return Color.white
	return types[type].color


func get_type_size(type: int) -> Vector2:
	if type < 0 or type >= types.size():
		printerr("Invalid type: " + str(type))
		return Vector2.ONE
	return types[type].size


func new_type(label := "Type", color := Color.white, size := Vector2(8, 8), multiple:= true, connections := [[], [], [], []]) -> Dictionary:
	return {
		"name": label,
		"color": color,
		"size": size,
		"multiple": multiple,
		"connections": connections
		}


#updates pos and scale on each node
func update_nodes() -> void:
	for child in get_children():
		if child is ShyGraphNode:
			child.update_position()
			child.rect_scale = Vector2.ONE / transform.get_scale()


#get slot from node
func get_slot(node_name:String, slot: int) -> Dictionary:
	var node: ShyGraphNode = get_node(node_name)
	if node:
		return node.get_slot(slot)
	return {}


func delete_selected() -> void:
	for i in selected_nodes:
		i.delete()
	selected_nodes = []


func copy_selected() -> void:
	for i in selected_nodes:
		add_child(i.copy())
	selected_nodes = []


func add_type(type := {}) -> void:
	if !type:
		type = new_type()
	types.append(type)


# private


func _create_line(connection: Dictionary) -> Dictionary:
	var from: Dictionary = connection.from
	var to: Dictionary = connection.to
	if !has_node(from.node):
		printerr("node not found: %s"%(from.node))
		remove_connection(connection)
		return {"line": [], "colors": []}
	var from_node = get_node(from.node)
	var from_pos = from_node.get_slot_offset(from.slot)
	var from_slot = get_slot(from.node, from.slot)
	var from_color = get_type_color(from_slot.type)
	var from_side = SIDES[from_slot.side]

	var to_pos: Vector2
	var to_color := Color.white
	var to_side := Vector2.ZERO
	if to:
		var to_node = get_node(to.node)
		var to_slot = get_slot(to.node, to.slot)
		to_pos = to_node.get_slot_offset(to.slot)
		to_color = get_type_color(to_slot.type)
		to_side = SIDES[to_slot.side]
	else:
		to_pos = position_to_offset(get_local_mouse_position())

	var line : PoolVector2Array = []
	var colors : PoolColorArray = []
	match line_type:
		line_types.line:
			line = [from_pos, to_pos]
			colors = [from_color, to_color]

		line_types.bezier:
			var curve = Curve2D.new()
			var weight = get_constant("bezier_len_pos", "GraphEdit")
			curve.add_point(from_pos, from_side * weight, from_side * weight)
			curve.add_point(to_pos, to_side * weight, to_side * weight)
			line = curve.get_baked_points()
			var gradient = Gradient.new()
			gradient.colors = [from_color, to_color]
			for i in line.size():
				colors.append(gradient.interpolate(1.0 / line.size() * i))
	return {"line": line, "colors": colors}


func _draw_connections() -> void:
	for i in connections:
		var line_data = _create_line(i)
		draw_polyline_colors(line_data.line, line_data.colors, line_width)


func _draw_create_connection() -> void:
	if create_connection_from:# todo add check
		if !hover_slot or _is_connection_allowed(create_connection_from, hover_slot):
			var line_data = _create_line({
				"from": create_connection_from,
				"to": hover_slot,
				})
			draw_polyline_colors(line_data.line, line_data.colors)


func _load_nodes() -> void:
	node_menu.clear()
	nodes = {}
	
	if node_folder:
		var dir := Directory.new()
		if dir.open(node_folder):
			dir.list_dir_begin()
			var file = dir.get_next()
			while file != "":
				if not file.begins_with("_") and file.get_extension() in [".tscn", ".scn", ".gd"]:
					var node = load(node_folder + "/" + file)
					var node_name = file.get_basename()
					nodes[node_name] = node
					node_menu.add_item(node_name)
			dir.list_dir_end()
	for node in get_children():
		if node is ShyGraphNode:
			node_menu.add_item(node.name)
			nodes[node.name] = node
			remove_child(node)
	emit_signal("nodes_loaded")


func _start_drag(from: Dictionary) -> void:
	create_connection_from = from


func _end_drag(to := {}) -> void:
	if create_connection_from:
		if to:
			add_connection(create_connection_from, to)
	create_connection_from = {}
	update()


func _create_node_instance(node, data := {}) -> ShyGraphNode:
	if node is Node:
		node = node.duplicate(7)
	elif node is PackedScene:
		node = node.instance()
	elif node is Script:
		node = node.new()
	
	if node is ShyGraphNode:
		node.load_data(data)
		node.rect_scale = Vector2.ONE / transform.get_scale()
		node.connect("moved", self, "_on_node_moved", [node])
		node.connect("selected", self, "_on_node_selected", [node])
		node.connect("deselected", self, "_on_node_deselected", [node])
		node.connect("delete", self, "_on_node_delete", [node])
		node.connect("request_deselect", self, "_on_node_request_deselect")
		add_child(node, true)
	return node


func _break_connections() -> void:
	var list = []
	for connection in connections:
		var line = _create_line(connection).line
		if Geometry.intersect_polyline_with_polygon_2d(line, [break_from, break_from + Vector2.ONE, get_local_mouse_position()]):
			list.append(connection)
	for i in list:
		remove_connection(i)
	break_from = Vector2.ZERO


func _start_select_drag() -> void:
	select_from = position_to_offset(get_local_mouse_position())


func _end_select_drag() -> void:
	var rect = Rect2(select_from, position_to_offset(get_local_mouse_position()) - select_from)
	var nodes := []
	for i in get_children():
		if i is ShyGraphNode:
			if i.get_rect().intersects(rect):
				nodes.append(i)
	select_multiple(nodes)
	select_from = Vector2.ZERO
	update()


func _is_connection_allowed(from: Dictionary, to: Dictionary) -> bool:
	var from_slot = get_node(from.node).get_slot(from.slot)
	var to_slot = get_node(to.node).get_slot(to.slot)
	var conns = types[from_slot.type].connections
	if to_slot.type in conns[from_slot.side]:
		return true
	conns = types[to_slot.type].connections
	if from_slot.type in conns[to_slot.side]:
		return true
	return false


func _disconnect_slot(node: String, slot: int) -> void:
	for connection in connections:
		if connection.from.node == node and connection.from.slot == slot:
			remove_connection(connection)
		elif connection.to.node == node and connection.to.slot == slot:
			remove_connection(connection)


func _update_theme() -> void:
	._update_theme()
	if has_color("break_line_color", ""):
		break_line_color = get_color("break_line_color", "")
	if has_constant("break_line_width", ""):
		break_line_width = get_constant("break_line_width", "")
	if has_constant("line_width", ""):
		line_width = get_constant("line_width", "")
	if has_color("selection_fill_color", ""):
		selection_fill_color = get_color("selection_fill_color", "")
	if has_color("selection_stroke_color", ""):
		selection_stroke_color = get_color("selection_stroke_color", "")
	if has_constant("selection_stroke_width", ""):
		selection_stroke_width = get_constant("selection_stroke_width", "")