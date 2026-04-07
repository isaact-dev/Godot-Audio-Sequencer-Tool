@tool
extends EditorPlugin
var dock
var dock_ui

func _enable_plugin():
	print("Godot Audio Sequencer Tool enabled")



func _disable_plugin():
	print("Godot Audio Sequencer Tool disabled")




func _enter_tree():
	dock_ui = preload("res://addons/sequencer_tool/ui/sequencer_dock.tscn").instantiate()

	dock = EditorDock.new()
	dock.add_child(dock_ui)

	dock.title = "Audio Sequencer"
	dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	dock.available_layouts = EditorDock.DOCK_LAYOUT_HORIZONTAL

	dock_ui.set_editor_undo_redo(get_undo_redo())

	add_dock(dock)


func _exit_tree():
	remove_dock(dock)
	dock.free()
	dock = null
	dock_ui = null
