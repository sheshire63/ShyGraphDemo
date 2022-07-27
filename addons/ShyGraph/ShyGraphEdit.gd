tool 
extends Control


class_name ShyGraphEdit


enum line_types {line, bezier}
const SIDES = {
		ShyGraphNode.SIDE.LEFT: Vector2.LEFT,
		ShyGraphNode.SIDE.RIGHT: Vector2.RIGHT,
		ShyGraphNode.SIDE.TOP: Vector2.UP,
		ShyGraphNode.SIDE.BOTTOM: Vector2.DOWN,
		}
const break_line_key := "shy_graph_break_lines"


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
var data := {}
var types := [] setget _set_types
#	"name": "",
#	"color": Color.white,
#   "connections": [], #sides disabled flag #omit this we just need to not set it to the wrong sides in the node
#	do we need to store the allowed sided from side(maybe even per connection)
# }
func _set_types(new) -> void:
	for i in new.size():
		if !new[i]:
			new[i] = new_type()
	types = new
	update_nodes()
export(line_types) var line_type := line_types.line
export var  grid_step := 128

var nodes := {}
var transform := Transform2D.IDENTITY
var connections := []
var create_connection_from := {}
var hover_slot := {}
var break_from: Vector2
var selected_nodes := []
var select_from : Vector2

var is_editor := true


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
		{
			"name": "data",
			"type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_STORAGE,
		}]
	return list


func _init(work_in_editor := false) -> void: #we need this so the graph can be used in the editor
	if Engine.editor_hint:
		is_editor = !work_in_editor
	else:
		is_editor = false
		

func _ready() -> void:
	if is_editor:
		return
	_load_nodes()


func _draw() -> void:
	_draw_grid()
	for i in connections:#todo move the get stuff to draw_link
		var line_data = _create_line(i)
		draw_polyline_colors(line_data.line, line_data.colors)
	if create_connection_from:
		var line_data = _create_line({
			"from": create_connection_from,
			"to": hover_slot,
			})
		draw_polyline_colors(line_data.line, line_data.colors)
	if break_from:
		draw_line(break_from, get_local_mouse_position(), Color.red)
	if select_from:
		draw_rect(Rect2(select_from, get_local_mouse_position() - select_from), Color(0.5, 0.5, 0.5, 0.5))


func _process(delta: float) -> void:
	if create_connection_from or break_from or select_from:
		update()


func _input(event: InputEvent) -> void:
	if is_editor:
		return
	if event.is_action_released(break_line_key):
		break_from = Vector2.ZERO
		update()
	if event is InputEventKey:
		if event.scancode == KEY_DELETE:
			delete_selected()


func _gui_input(event: InputEvent) -> void:
	if is_editor:
		return
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == BUTTON_LEFT:
				create_connection_from = {}
				if Input.is_action_pressed(break_line_key):
					break_from = get_local_mouse_position()
				else:
					_start_select_drag()
				update()
			if event.button_index == BUTTON_RIGHT:
				node_menu.popup(Rect2(event.position, node_menu.rect_size))
			if event.button_index == BUTTON_WHEEL_UP:
				scale(0.909091)
			if event.button_index == BUTTON_WHEEL_DOWN:
				scale(1.1)
		else:
			if event.button_index == BUTTON_LEFT:
				if Input.is_action_pressed(break_line_key):
					_break_connections()
				_end_select_drag()
				
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(BUTTON_MIDDLE):
			transform = transform.translated(-event.relative)
			update()
			update_nodes()
		if Input.is_mouse_button_pressed(BUTTON_LEFT) and Input.is_action_pressed(break_line_key):
			update()
			

func _on_Nodes_id_pressed(id:int) -> void:
	var node =_create_node_instance(nodes.values()[id])
	node.type = nodes.keys()[id]
	node.offset = position_to_offset(node_menu.rect_position)


func _on_node_moved(amount: Vector2, node: ShyGraphNode) -> void:
	for i in selected_nodes:
		if i == node:
			continue
		i.offset += amount
	update()


func _on_node_selected(multiple: bool, node: ShyGraphNode) -> void:
	if !multiple:
		deselect()
	selected_nodes.append(node)


func _on_node_deselected(node: ShyGraphNode) -> void:
	selected_nodes.erase(node)


func _on_node_request_deselect() -> void:
	deselect()
#--------------------------------------------------------------


func deselect() -> void:
	for i in selected_nodes:
		i.selected = false
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


func scale(scale: float) -> void:
	var mouse_from = position_to_offset(get_local_mouse_position())
	transform = transform.scaled(Vector2.ONE * scale)
	var mouse_to = position_to_offset(get_local_mouse_position())
	transform.origin += mouse_from - mouse_to
	update()
	update_nodes()


func init_drag(slot: Dictionary) -> void:
	if create_connection_from:
		_end_drag(slot)
	else:
		_start_drag(slot)


func offset_to_position(offset: Vector2) -> Vector2:
	return transform.affine_inverse().xform(offset)


func position_to_offset(position: Vector2) -> Vector2:
	return transform.xform(position)


func save_data() -> Dictionary:
	data = {"nodes": {}, "connections": []}
	for child in get_children():
		if child is ShyGraphNode:
			data.nodes[child.name] = child.save_data()
	return data


func load_data(data: Dictionary) -> void:
	connections = data.connections
	for i in data.nodes:
		var node = _create_node_instance(nodes[i.type], data.nodes[i])
		

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
	

#--------------------------------------------------------------


func _draw_grid() -> void:
	var from = position_to_offset(Vector2.ZERO)
	var to = position_to_offset(rect_size)
	var x = stepify(from.x, grid_step)
	var test = Vector2(128, 128)
	while x < to.x:
		var pos = offset_to_position(Vector2.ONE * x)
		draw_line(Vector2(pos.x, 0), Vector2(pos.x, rect_size.y), Color.gray)
		x += grid_step
	var y = stepify(from.y, grid_step)
	while y < to.y:
		var pos = offset_to_position(Vector2.ONE * y)
		draw_line(Vector2(0, pos.y), Vector2(rect_size.x, pos.y), Color.gray)
		y += grid_step


func _create_line(connection: Dictionary) -> Dictionary:
	var from: Dictionary = connection.from
	var to: Dictionary = connection.to
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
			curve.add_point(from_pos, from_side * 128, from_side * 128)
			curve.add_point(to_pos, to_side * 128, to_side * 128)
			line = curve.get_baked_points()
			var gradient = Gradient.new()
			gradient.colors = [from_color, to_color]
			for i in line.size():
				colors.append(gradient.interpolate(1.0 / line.size() * i))
	for i in line.size():
		line[i] = offset_to_position(line[i])
	return {"line": line, "colors": colors}


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
		node.connect("request_deselect", self, "_on_node_request_deselect")
		add_child(node)
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
	select_from = get_local_mouse_position()


func _end_select_drag() -> void:
	var rect = Rect2(select_from, get_local_mouse_position() - select_from)
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
