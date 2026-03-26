@tool
extends VBoxContainer
@onready var status_label = $StatusLabel
@onready var timeline = $HSplitContainer/TimelineBox/TimelinePanel/ScrollContainer/TimelineControl

func _ready() -> void:
	status_label.text = timeline._build_status_text()
func _on_button_new_pressed():
	print('new')


func _on_button_open_pressed():
	print('open')


func _on_button_save_pressed():
	print('save')


func _on_button_play_pressed():
	print('play')


func _on_button_pause_pressed():
	print('pause')

func _on_timeline_control_status_text_changed(text: String) -> void:
	status_label.text = text
