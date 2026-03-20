@tool
extends EditorPlugin
var dock

func _enable_plugin():
	print("Godot Audio Sequencer Tool enabled")



func _disable_plugin():
	print("Godot Audio Sequencer Tool disabled")



func _enter_tree():
	var dock_scene = preload("res://addons/sequencer_tool/ui/sequencer_dock.tscn").instantiate()
	# Create the dock and add the loaded scene to it.
	dock = EditorDock.new()
	dock.add_child(dock_scene)
	# Add dock specifications
	dock.title = "Audio Sequencer"
	dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	dock.available_layouts = EditorDock.DOCK_LAYOUT_HORIZONTAL
	
	add_dock(dock)
	


func _exit_tree():
	remove_dock(dock)
	dock.free()
