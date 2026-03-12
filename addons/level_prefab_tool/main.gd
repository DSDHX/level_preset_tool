@tool
extends EditorPlugin

var dock_scene: PackedScene = preload("res://addons/level_prefab_tool/dock_panel.tscn")
var dock_instance : EditorDock

# ================= state var =================
var is_drawing_mode := false
var is_dragging := false
var start_pos := Vector2.ZERO
var current_pos := Vector2.ZERO
var current_node2d: Node2D = null
# ==========================================

func _enter_tree() -> void:
	var dock_control = dock_scene.instantiate() as Control
	
	dock_instance = EditorDock.new()
	dock_instance.title = "Level Prefab"
	dock_instance.default_slot = EditorDock.DOCK_SLOT_LEFT_UR
	
	dock_instance.add_child(dock_control)
	
	add_dock(dock_instance)
	
	var draw_button = dock_control.get_node_or_null("VBoxContainer/DrawModeButton")
	if draw_button:
		draw_button.toggled.connect(_on_draw_mode_toggled)
		
	var exprot_button = dock_control.get_node_or_null("VBoxContainer/ExportButton")
	if exprot_button:
		exprot_button.pressed.connect(_on_export_button_pressed)
	
	print("Level Prefab Tool is now active!")

func _exit_tree() -> void:
	if dock_instance:
		remove_dock(dock_instance)
		dock_instance.queue_free()
	print("Level Prefab Tool has been disabled!")

func _on_draw_mode_toggled(button_pressed: bool) -> void:
	is_drawing_mode = button_pressed
	is_dragging = false
	
	#if is_drawing_mode:
		#print("Drawing mode is now ACTIVE!")
	#else:
		#print("Drawing mode is now DISABLED.")
	
	update_overlays()

func _handles(object: Object) -> bool:
	if object is Node2D:
		current_node2d = object
		return true
	return false

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not is_drawing_mode:
		return false
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			start_pos = event.position
			current_pos = event.position
			update_overlays()
			return true
		else:
			is_dragging = false
			update_overlays()
			
			_create_brick(start_pos, current_pos)
			
			return true
			
	if event is InputEventMouseMotion and is_dragging:
		current_pos = event.position
		update_overlays()
		return true
	
	return false

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if is_drawing_mode and is_dragging:
		var rect = Rect2(start_pos, current_pos - start_pos).abs()
		
		overlay.draw_rect(rect, Color(0.2, 0.6, 1.0, 0.3), true)
		overlay.draw_rect(rect, Color(0.2, 0.6, 1.0, 0.8), false, 2.0)

func _create_brick(start_p: Vector2, end_p: Vector2) -> void:
	var root = EditorInterface.get_edited_scene_root()
	
	var canvas_item := root as CanvasItem
	if not canvas_item:
		canvas_item = current_node2d
		
	if not canvas_item:
		push_warning("The root node for the current scene was not found! Please open or create a scene first.")
		return
	
	var canvas_transform = EditorInterface.get_editor_viewport_2d().get_global_canvas_transform()
	var world_start := canvas_transform.affine_inverse() * start_p
	var world_end := canvas_transform.affine_inverse() * end_p
	
	var rect := Rect2(world_start, world_end - world_start).abs()
	var center := rect.position + rect.size / 2.0
	
	## === Debug-specific code begins ===
	#print("--- Debug Coordinate ---")
	#print("Camera Origin (Pan): ", canvas_transform.origin)
	#print("Camera Scale (Zoom): ", canvas_transform.get_scale())
	#print("Calculated World Center: ", center)
	#print("------------------------")
	## === Debug-specific code ends ===
	
	if rect.size.x < 10.0 or rect.size.y < 10.0:
		return
	
	var body := StaticBody2D.new()
	body.global_position = center
	body.name = "BrickBody"
	
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.name = "Collision"
	
	var color_rect := ColorRect.new()
	color_rect.color = Color(0.8, 0.4, 0.2)
	color_rect.size = rect.size
	color_rect.position = -rect.size / 2.0
	color_rect.name = "Visual"
	
	root.add_child(body, true)
	body.add_child(color_rect)
	body.add_child(collision)
	
	body.owner = root
	collision.owner = root
	color_rect.owner = root
	
	print("Brick successfully generated! Position: ", center, ", Size: ", rect.size)

func _on_export_button_pressed() -> void:
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		push_warning("No exportable scenes!")
		return
	
	var level_data := []
	
	for child in root.get_children():
		if child is StaticBody2D and child.name.begins_with("BrickBody"):
			var pos_x = child.global_position.x
			var pos_y = child.global_position.y
			
			var size_x = 0.0
			var size_y = 0.0
			var collision = child.get_node_or_null("Collision")
			if collision and collision.shape is RectangleShape2D:
				size_x = collision.shape.size.x
				size_y = collision.shape.size.y
			
			var brick_dict := {
				"position_x": pos_x,
				"position_y": pos_y,
				"size_x": size_x,
				"size_y": size_y
			}
			level_data.push_back(brick_dict)
	
	if level_data.is_empty():
		push_warning("No bricks were found in the scene. Export canceled.")
		return
	
	var json_string = JSON.stringify(level_data, "\t")
	
	var file = FileAccess.open("res://level_data.json", FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("Level export successful! A total of ", level_data.size(), " bricks were exported.")
		print("The file has been saved at: res://level_data.json")
		
		EditorInterface.get_resource_filesystem().scan()
	else:
		push_error("Unable to save JSON file!")
