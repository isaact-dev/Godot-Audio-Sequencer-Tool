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
@onready var bars_slider = $HSplitContainer/SettingsHost/TimelineSettings/Bars/BarsSlider
@onready var tracks_list = $HSplitContainer/SettingsHost/TimelineSettings/Tracks/ScrollContainer/TracksList
@onready var track_add_button = $HSplitContainer/SettingsHost/TimelineSettings/Tracks/TrackHeader/TrackAddButton
@onready var delete_clip_button = $ToolBar/ButtonDeleteClip
@onready var new_sequence_dialog = $NewSequenceDialog
@onready var new_bars_spin = $NewSequenceDialog/MarginContainer/VBoxContainer/NewBarsSpin
@onready var new_beats_spin = $NewSequenceDialog/MarginContainer/VBoxContainer/NewBeatsSpin
@onready var new_subdivisions_spin = $NewSequenceDialog/MarginContainer/VBoxContainer/NewSubdivisionsSpin
@onready var open_sequence_dialog = $OpenSequenceDialog
@onready var save_sequence_dialog = $SaveSequenceDialog
@onready var bpm_slider = $HSplitContainer/SettingsHost/TimelineSettings/BPM/BPMSlider
@onready var track_delete_confirm_dialog = $TrackDeleteConfirmDialog

var editor_undo_redo: EditorUndoRedoManager = null

var current_sequence_path: String = ""

var _updating_clip_settings_ui: bool = false

var pending_track_delete_index: int = -1

func _ready() -> void:
	if timeline == null:
		push_error("TimelineControl not found in sequencer_dock.gd")
		return

	if editor_undo_redo != null:
		timeline.set_editor_undo_redo(editor_undo_redo)


	status_label.text = timeline._build_status_text()

	delete_clip_button.disabled = true

	track_spin.min_value = 0
	track_spin.max_value = max(0, timeline.track_count - 1)
	track_spin.step = 1

	start_spin.min_value = 0.0
	start_spin.step = 0.1

	length_spin.min_value = timeline.min_clip_length
	length_spin.step = 0.1

	clip_settings.visible = false
	timeline_settings.visible = true


	bars_slider.min_value = 1
	bars_slider.step = 1
	bars_slider.value = timeline.bars

	bpm_slider.min_value = 1
	bpm_slider.max_value = 300
	bpm_slider.step = 1
	bpm_slider.value = timeline.bpm

	_refresh_tracks_list(timeline.get_track_names())
	_clear_clip_settings_ui()
	new_bars_spin.min_value = 1
	new_bars_spin.step = 1
	new_bars_spin.rounded = true

	new_beats_spin.min_value = 1
	new_beats_spin.step = 1
	new_beats_spin.rounded = true

	new_subdivisions_spin.min_value = 1
	new_subdivisions_spin.step = 1
	new_subdivisions_spin.rounded = true

	new_sequence_dialog.get_ok_button().text = "Create"

	open_sequence_dialog.access = FileDialog.ACCESS_RESOURCES
	open_sequence_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_sequence_dialog.filters = PackedStringArray(["*.json ; Sequencer Tool JSON"])

	save_sequence_dialog.access = FileDialog.ACCESS_RESOURCES
	save_sequence_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_sequence_dialog.filters = PackedStringArray(["*.json ; Sequencer Tool JSON"])
	save_sequence_dialog.current_file = "sequence.json"

func set_editor_undo_redo(value: EditorUndoRedoManager) -> void:
	editor_undo_redo = value
	if timeline != null:
		timeline.set_editor_undo_redo(value)

func _clear_clip_settings_ui() -> void:
	_updating_clip_settings_ui = true
	name_edit.text = ""
	track_spin.value = track_spin.min_value
	start_spin.value = start_spin.min_value
	length_spin.value = length_spin.min_value
	delete_clip_button.disabled = true
	_updating_clip_settings_ui = false

func _sync_clip_settings_ui(clip_index: int, clip_data: Dictionary) -> void:
	_updating_clip_settings_ui = true

	if clip_index < 0 or clip_data.is_empty():
		name_edit.text = ""
		track_spin.value = track_spin.min_value
		start_spin.value = start_spin.min_value
		length_spin.value = length_spin.min_value
	else:
		delete_clip_button.disabled = false
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

func _sync_timeline_settings_ui() -> void:
	if bars_slider.value != timeline.bars:
		bars_slider.value = timeline.bars

	if bpm_slider.value != timeline.bpm:
		bpm_slider.value = timeline.bpm

func _save_sequence_to_path(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for saving: %s" % path)
		return

	var sequence_data = timeline.get_sequence_data()
	file.store_string(JSON.stringify(sequence_data, "\t"))
	current_sequence_path = path

func _load_sequence_from_path(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file for loading: %s" % path)
		return

	var content := file.get_as_text()
	var parsed = JSON.parse_string(content)

	if not parsed is Dictionary:
		push_error("Invalid sequence file: %s" % path)
		return

	timeline.load_sequence_data(parsed)
	current_sequence_path = path
	_sync_timeline_settings_ui()

func _on_new_sequence_dialog_confirmed() -> void:
	timeline.create_new_sequence(
		int(new_bars_spin.value),
		int(new_beats_spin.value),
		int(new_subdivisions_spin.value)
	)

	current_sequence_path = ""
	_sync_timeline_settings_ui()

func _on_open_sequence_dialog_file_selected(path: String) -> void:
	_load_sequence_from_path(path)

func _on_save_sequence_dialog_file_selected(path: String) -> void:
	_save_sequence_to_path(path)

func _on_button_add_clip_pressed() -> void:
	timeline.add_clip()

func _on_button_delete_clip_pressed() -> void:
	timeline.delete_selected_clip()

func _on_bars_slider_value_changed(value: float) -> void:
	timeline.set_bars(int(value))

func _refresh_tracks_list(track_names: Array) -> void:
	for child in tracks_list.get_children():
		child.queue_free()

	for i in range(track_names.size()):
		var row := HBoxContainer.new()

		var index_label := Label.new()
		index_label.text = "%d" % [i + 1]
		index_label.custom_minimum_size = Vector2(36, 0)
		index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		index_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		var row_name_edit := LineEdit.new()
		row_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_name_edit.text = str(track_names[i])
		row_name_edit.placeholder_text = "Track %d" % [i + 1]
		row_name_edit.text_submitted.connect(_on_track_name_submitted.bind(i, row_name_edit))
		row_name_edit.focus_exited.connect(_on_track_name_focus_exited.bind(i, row_name_edit))

		var up_button := Button.new()
		up_button.text = "↑"
		up_button.disabled = i == 0
		up_button.pressed.connect(_on_track_move_up_pressed.bind(i))

		var down_button := Button.new()
		down_button.text = "↓"
		down_button.disabled = i == track_names.size() - 1
		down_button.pressed.connect(_on_track_move_down_pressed.bind(i))

		var delete_button := Button.new()
		delete_button.text = "x"
		delete_button.disabled = track_names.size() <= 1
		delete_button.pressed.connect(_on_track_delete_pressed.bind(i))

		row.add_child(index_label)
		row.add_child(row_name_edit)
		row.add_child(up_button)
		row.add_child(down_button)
		row.add_child(delete_button)

		tracks_list.add_child(row)

func _on_timeline_control_tracks_changed(track_names: Array) -> void:
	track_spin.max_value = max(0, timeline.track_count - 1)
	for child in tracks_list.get_children():
		for sub in child.get_children():
			if sub is LineEdit and sub.has_focus():
				return

	_refresh_tracks_list(track_names)

func _on_track_add_button_pressed() -> void:
	timeline.add_track()

func _on_track_delete_pressed(track_index: int) -> void:
	pending_track_delete_index = track_index
	track_delete_confirm_dialog.popup_centered()

func _on_track_move_up_pressed(track_index: int) -> void:
	timeline.move_track(track_index, track_index - 1)

func _on_track_move_down_pressed(track_index: int) -> void:
	timeline.move_track(track_index, track_index + 1)

func _on_track_name_submitted(_text: String, track_index: int, line_edit: LineEdit) -> void:
	timeline.rename_track(track_index, line_edit.text)
	line_edit.release_focus()

func _on_track_name_focus_exited(track_index: int, line_edit: LineEdit) -> void:
	timeline.rename_track(track_index, line_edit.text)
	_refresh_tracks_list(timeline.get_track_names())

func _on_button_new_pressed():
	new_bars_spin.value = timeline.bars
	new_beats_spin.value = timeline.beats_per_bar
	new_subdivisions_spin.value = timeline.subdivisions_per_beat
	new_sequence_dialog.popup_centered()


func _on_button_open_pressed():
	open_sequence_dialog.popup_centered_ratio()

func _on_button_save_pressed():
	if current_sequence_path.is_empty():
		save_sequence_dialog.popup_centered_ratio()
		return

	_save_sequence_to_path(current_sequence_path)


func _on_button_play_pressed():
	timeline.play()

func _on_button_pause_pressed():
	timeline.pause()

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


func _on_bpm_slider_value_changed(value):
	timeline.set_bpm(value)


func _on_track_delete_confirm_dialog_confirmed():
	if pending_track_delete_index < 0:
		return

	timeline.remove_track(pending_track_delete_index)
	pending_track_delete_index = -1


func _on_track_delete_confirm_dialog_canceled():
	pending_track_delete_index = -1
