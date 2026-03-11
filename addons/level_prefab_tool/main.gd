@tool
extends EditorPlugin

var dock_scene: PackedScene = preload("res://addons/level_prefab_tool/dock_panel.tscn")
var dock_instance : Control

# ================= state var =================
var is_drawing_mode := false
var is_dragging := false
var start_pos := Vector2.ZERO
var current_pos := Vector2.ZERO
# ==========================================

func _enter_tree() -> void:
	dock_instance = dock_scene.instantiate() as Control
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, dock_instance)
	
	var draw_button = dock_instance.get_node_or_null("VBoxContainer/DrawModeButton")
	if draw_button:
		draw_button.toggled.connect(_on_draw_mode_toggled)
	
	print("Level Prefab Tool is now active!")

func _exit_tree() -> void:
	if dock_instance:
		remove_control_from_docks(dock_instance)
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
	return object is Node2D

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
