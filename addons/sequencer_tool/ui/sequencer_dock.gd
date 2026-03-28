@tool
extends VBoxContainer

@onready var status_label = $StatusLabel
@onready var timeline = $HSplitContainer/TimelineBox/TimelinePanel/ScrollContainer/TimelineControl
@onready var name_edit = $HSplitContainer/SettingsHost/ClipSettings/ClipNameEdit
@onready var track_spin = $HSplitContainer/SettingsHost/ClipSettings/ClipTrackSpin
@onready var timeline_settings: VBoxContainer = $HSplitContainer/SettingsHost/TimelineSettings
@onready var clip_settings: VBoxContainer = $HSplitContainer/SettingsHost/ClipSettings
@onready var start_spin = $HSplitContainer/SettingsHost/ClipSettings/ClipStartSpin
@onready var length_spin = $HSplitContainer/SettingsHost/ClipSettings/ClipLengthSpin
@onready var settings_host = $HSplitContainer/SettingsHost


var _updating_clip_settings_ui: bool = false

func _ready() -> void:
	if timeline == null:
		push_error("TimelineControl not found in sequencer_dock.gd")
		return

	status_label.text = timeline._build_status_text()

	track_spin.min_value = 0
	track_spin.max_value = max(0, timeline.track_count - 1)
	track_spin.step = 1

	start_spin.min_value = 0.0
	start_spin.step = 0.1

	length_spin.min_value = timeline.min_clip_length
	length_spin.step = 0.1

	clip_settings.visible = false
	timeline_settings.visible = true

	await _lock_settings_host_height()
	_clear_clip_settings_ui()

func _clear_clip_settings_ui() -> void:
	_updating_clip_settings_ui = true
	name_edit.text = ""
	track_spin.value = track_spin.min_value
	_updating_clip_settings_ui = false


func _sync_clip_settings_ui(clip_index: int, clip_data: Dictionary) -> void:
	_updating_clip_settings_ui = true

	if clip_index < 0 or clip_data.is_empty():
		name_edit.text = ""
		track_spin.value = track_spin.min_value
		start_spin.value = start_spin.min_value
		length_spin.value = length_spin.min_value
	else:
		var clip_length := float(clip_data.get("length", timeline.min_clip_length))
		var max_start := max(0.0, float(timeline.bars * timeline.beats_per_bar * timeline.subdivisions_per_beat) - clip_length)
		var clip_start := float(clip_data.get("start", 0.0))
		var max_length := max(timeline.min_clip_length, float(timeline.bars * timeline.beats_per_bar * timeline.subdivisions_per_beat) - clip_start)
		var clip_name := str(clip_data.get("name", ""))

		if not name_edit.has_focus() and name_edit.text != clip_name:
			name_edit.text = clip_name


		var clip_track := int(clip_data.get("track", 0))

		if track_spin.value != clip_track:
			track_spin.value = clip_track

		start_spin.max_value = max_start
		if start_spin.value != clip_start:
			start_spin.value = clip_start

		length_spin.min_value = timeline.min_clip_length
		length_spin.max_value = max_length
		if length_spin.value != clip_length:
			length_spin.value = clip_length


	_updating_clip_settings_ui = false


func _lock_settings_host_height() -> void:
	var timeline_settings_was_visible := timeline_settings.visible
	var clip_settings_was_visible := clip_settings.visible

	timeline_settings.visible = true
	clip_settings.visible = true

	await get_tree().process_frame

	var timeline_height := timeline_settings.get_combined_minimum_size().y
	var clip_height := clip_settings.get_combined_minimum_size().y
	settings_host.custom_minimum_size.y = max(timeline_height, clip_height)

	timeline_settings.visible = timeline_settings_was_visible
	clip_settings.visible = clip_settings_was_visible


func _on_button_new_pressed():
	print("new")

func _on_button_open_pressed():
	print("open")

func _on_button_save_pressed():
	print("save")

func _on_button_play_pressed():
	print("play")

func _on_button_pause_pressed():
	print("pause")

func _on_timeline_control_status_text_changed(text: String) -> void:
	status_label.text = text

func _on_timeline_control_selected_clip_changed(clip_index: int, clip_data: Dictionary) -> void:
	if clip_index < 0 or clip_data.is_empty():
		_clear_clip_settings_ui()
		timeline_settings.visible = true
		clip_settings.visible = false
		return
	_sync_clip_settings_ui(clip_index, clip_data)
	timeline_settings.visible = false
	clip_settings.visible = true


func _on_clip_name_edit_text_changed(new_text: String) -> void:
	if _updating_clip_settings_ui:
		return
	timeline.set_selected_clip_name(new_text)

func _on_clip_track_spin_value_changed(value: float) -> void:
	if _updating_clip_settings_ui:
		return
	timeline.set_selected_clip_track(int(value))

func _on_clip_start_spin_value_changed(value: float) -> void:
	if _updating_clip_settings_ui:
		return
	timeline.set_selected_clip_start(value)

func _on_clip_length_spin_value_changed(value: float) -> void:
	if _updating_clip_settings_ui:
		return
	timeline.set_selected_clip_length(value)

func _on_clip_close_button_pressed() -> void:
	timeline.clear_selected_clip()
