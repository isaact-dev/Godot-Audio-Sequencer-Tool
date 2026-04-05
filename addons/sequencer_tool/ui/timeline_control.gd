@tool
extends Control
class_name TimelineControl

@export var bars: int = 8
@export var beats_per_bar: int = 4
@export var subdivisions_per_beat: int = 4
@export var track_count: int = 4
@export var lane_height: float = 48.0
@export var pixels_per_subdivision: float = 24.0
@export var header_height: float = 32.0
@export var clip_vertical_padding: float = 6.0
@export var clip_horizontal_padding: float = 2.0
@export var snap_enabled: bool = true
@export var keyboard_nudge_amount: float = 1.0
@export var keyboard_micro_nudge_amount: float = 0.1
@export var auto_scroll_edge_threshold: float = 48.0
@export var auto_scroll_speed: float = 16.0
@export var visible_scroll_margin: float = 24.0
@export var min_clip_length: float = 0.85
@export var resize_handle_width: float = 10.0

var background_color := Color(0.10, 0.10, 0.12)
var header_color := Color(0.16, 0.16, 0.20)
var header_separator_color := Color(0.0, 0.0, 0.0, 0.45)

var lane_color_a := Color(0.14, 0.14, 0.16)
var lane_color_b := Color(0.12, 0.12, 0.14)

var subdivision_line_color := Color(0.20, 0.20, 0.24)
var beat_line_color := Color(0.32, 0.32, 0.38)
var bar_line_color := Color(0.55, 0.55, 0.65)

var bar_number_color := Color(0.92, 0.92, 0.96)
var clip_text_color := Color(1.0, 1.0, 1.0)
var clip_outline_color := Color(0.0, 0.0, 0.0, 0.45)

var fake_clips: Array[Dictionary] = []

var track_names: Array[String] = []

var selected_clip_index: int = -1
var hovered_clip_index: int = -1
var hovered_resize_clip_index: int = -1

var selected_clip_outline_color := Color(1.0, 0.9, 0.35, 1.0)
var selected_clip_overlay_color := Color(1.0, 1.0, 1.0, 0.08)
var hovered_clip_outline_color := Color(1.0, 1.0, 1.0, 0.38)
var hovered_clip_overlay_color := Color(1.0, 1.0, 1.0, 0.05)

var is_dragging_clip: bool = false
var dragged_clip_index: int = -1
var drag_grab_offset: float = 0.0
var temporary_snap_override_active: bool = false
var drag_start_mouse_position: Vector2 = Vector2.ZERO

var is_resizing_clip: bool = false
var resized_clip_index: int = -1
var resize_grab_offset: float = 0.0
var resize_start_mouse_position: Vector2 = Vector2.ZERO

var resize_handle_color := Color(1.0, 1.0, 1.0, 0.18)
var active_resize_handle_color := Color(1.0, 0.9, 0.35, 0.95)


signal status_text_changed(text: String)
signal selected_clip_changed(clip_index: int, clip_data: Dictionary)
signal tracks_changed(track_names: Array)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(true)

	_create_demo_clips()
	_ensure_track_names_size()
	_update_timeline_size()
	call_deferred("_emit_status_text")
	call_deferred("_emit_selected_clip_changed")
	call_deferred("_emit_tracks_changed")
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _get_total_subdivisions() -> int:
	return bars * beats_per_bar * subdivisions_per_beat

func _get_total_width() -> float:
	return _get_total_subdivisions() * pixels_per_subdivision

func _get_total_height() -> float:
	return header_height + (track_count * lane_height)

func _get_bar_width() -> float:
	return beats_per_bar * subdivisions_per_beat * pixels_per_subdivision

func _update_timeline_size() -> void:
	custom_minimum_size = Vector2(_get_total_width(), _get_total_height())


func set_bars(value: int) -> void:
	bars = max(1, value)
	_update_timeline_size()
	queue_redraw()

func set_track_count(value: int) -> void:
	track_count = max(1, value)
	_ensure_track_names_size()

	for i in range(fake_clips.size()):
		var clip := fake_clips[i]
		if not clip.has("track"):
			continue
		clip["track"] = clamp(int(clip["track"]), 0, track_count - 1)
		fake_clips[i] = clip

	_update_timeline_size()
	_emit_status_text()
	_emit_selected_clip_changed()
	_emit_tracks_changed()
	queue_redraw()


func _timeline_to_x(position: float) -> float:
	return position * pixels_per_subdivision

func _x_to_timeline(x: float) -> float:
	return x / pixels_per_subdivision

func _y_to_track_index(y: float) -> int:
	var local_y := y - header_height

	if local_y < 0.0:
		return 0

	var track_index := int(floor(local_y / lane_height))
	return clamp(track_index, 0, track_count - 1)

func _track_to_y(track_index: int) -> float:
	return header_height + (track_index * lane_height)

func _get_clip_rect(clip: Dictionary) -> Rect2:
	var track_index: int = clip["track"]
	var start: float = clip["start"]
	var length: float = clip["length"]

	var x := _timeline_to_x(start) + clip_horizontal_padding
	var y := _track_to_y(track_index) + clip_vertical_padding
	var width := (length * pixels_per_subdivision) - (clip_horizontal_padding * 2.0)
	var height := lane_height - (clip_vertical_padding * 2.0)

	return Rect2(x, y, width, height)

func _get_clip_index_at_position(position: Vector2) -> int:
	for i in range(fake_clips.size() - 1, -1, -1):
		var clip := fake_clips[i]

		if not clip.has("track") or not clip.has("start") or not clip.has("length"):
			continue

		var track_index: int = clip["track"]
		var length: float = clip["length"]

		if track_index < 0 or track_index >= track_count:
			continue

		if length <= 0.0:
			continue

		var rect := _get_clip_rect(clip)

		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue

		if rect.has_point(position):
			return i

	return -1

func _build_status_text() -> String:
	var snap_text := "On" if _is_snap_active() else "Off"

	if selected_clip_index < 0 or selected_clip_index >= fake_clips.size():
		return "Selected: None | Start: - | Length: - | Snap: %s" % snap_text

	var clip := fake_clips[selected_clip_index]

	if not clip.has("name") or not clip.has("start") or not clip.has("length"):
		return "Selected: Invalid | Start: - | Length: - | Snap: %s" % snap_text

	var clip_name := str(clip["name"])
	var start: float = clip["start"]
	var length: float = clip["length"]
	var track: int = clip["track"]

	return "Selected: %s | Start: %.2f | Length: %.2f | Track: %d | Snap: %s" % [
		clip_name,
		start,
		length,
		track,
		snap_text
	]

func _emit_status_text() -> void:
	status_text_changed.emit(_build_status_text())

func _create_default_track_name(track_index: int) -> String:
	return "Track %d" % [track_index + 1]

func _ensure_track_names_size() -> void:
	while track_names.size() < track_count:
		track_names.append(_create_default_track_name(track_names.size()))

	while track_names.size() > track_count:
		track_names.remove_at(track_names.size() - 1)

func get_track_names() -> Array[String]:
	return track_names.duplicate()

func _emit_tracks_changed() -> void:
	tracks_changed.emit(get_track_names())


func _gui_input(event: InputEvent) -> void:
	_update_temporary_snap_override_from_event(event)

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if key_event.pressed:
			if key_event.keycode == KEY_LEFT:
				if key_event.shift_pressed:
					_nudge_selected_clip(-keyboard_micro_nudge_amount, false)
				else:
					_nudge_selected_clip(-keyboard_nudge_amount, true)

				accept_event()
				return

			elif key_event.keycode == KEY_RIGHT:
				if key_event.shift_pressed:
					_nudge_selected_clip(keyboard_micro_nudge_amount, false)
				else:
					_nudge_selected_clip(keyboard_nudge_amount, true)

				accept_event()
				return


	if event is InputEventMouseMotion:
		var mouse_motion_event := event as InputEventMouseMotion

		if not is_dragging_clip and not is_resizing_clip:
			_update_hovered_resize_handle(mouse_motion_event.position)
			_update_hovered_clip(mouse_motion_event.position)

		return


	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton

		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button_event.pressed:
				grab_focus()

				var clicked_resize_clip_index := _get_resize_handle_clip_index_at_position(mouse_button_event.position)

				if clicked_resize_clip_index != -1:
					selected_clip_index = clicked_resize_clip_index
					_emit_selected_clip_changed()
					_begin_clip_resize(clicked_resize_clip_index, mouse_button_event.position)
					return

				var clicked_clip_index := _get_clip_index_at_position(mouse_button_event.position)

				selected_clip_index = clicked_clip_index
				_emit_status_text()
				_emit_selected_clip_changed()

				if clicked_clip_index != -1:
					_begin_clip_drag(clicked_clip_index, mouse_button_event.position)
				else:
					queue_redraw()
			else:
				if is_resizing_clip:
					_end_clip_resize()
				else:
					_end_clip_drag()

				_update_hovered_resize_handle(mouse_button_event.position)
				_update_hovered_clip(mouse_button_event.position)


func _process(delta: float) -> void:
	if not is_dragging_clip and not is_resizing_clip:
		return

	temporary_snap_override_active = Input.is_key_pressed(KEY_SHIFT)

	var mouse_position := get_local_mouse_position()

	_auto_scroll_during_drag(mouse_position, delta)

	mouse_position = get_local_mouse_position()

	if is_resizing_clip:
		_update_clip_resize(mouse_position)
	elif is_dragging_clip:
		_update_clip_drag(mouse_position)


#Dragging

func _snap_timeline_position(position: float) -> float:
	if not _is_snap_active():
		return position

	return round(position)

func _update_cursor_shape() -> void:
	if is_resizing_clip or hovered_resize_clip_index != -1:
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
	elif is_dragging_clip:
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	elif hovered_clip_index != -1:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _begin_clip_drag(clip_index: int, mouse_position: Vector2) -> void:
	if clip_index < 0 or clip_index >= fake_clips.size():
		return
	drag_start_mouse_position = mouse_position
	var clip := fake_clips[clip_index]

	if not clip.has("start"):
		return

	var clip_start: float = clip["start"]
	var mouse_timeline_position := _x_to_timeline(mouse_position.x)

	is_dragging_clip = true
	dragged_clip_index = clip_index
	drag_grab_offset = mouse_timeline_position - clip_start

	selected_clip_index = clip_index
	hovered_clip_index = -1
	_update_cursor_shape()
	queue_redraw()


func _update_clip_drag(mouse_position: Vector2) -> void:
	if not is_dragging_clip or is_resizing_clip:
		return

	if dragged_clip_index < 0 or dragged_clip_index >= fake_clips.size():
		return

	if mouse_position.distance_to(drag_start_mouse_position) < 4.0:
		return

	var clip := fake_clips[dragged_clip_index]

	if not clip.has("start") or not clip.has("length") or not clip.has("track"):
		return

	var length: float = clip["length"]
	var mouse_timeline_position := _x_to_timeline(mouse_position.x)

	var new_start := mouse_timeline_position - drag_grab_offset
	new_start = _snap_timeline_position(new_start)

	var max_start := max(0.0, float(_get_total_subdivisions()) - length)
	new_start = clamp(new_start, 0.0, max_start)

	var new_track := _y_to_track_index(mouse_position.y)

	clip["start"] = new_start
	clip["track"] = new_track
	fake_clips[dragged_clip_index] = clip

	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()




func _end_clip_drag() -> void:
	if not is_dragging_clip:
		return

	is_dragging_clip = false
	dragged_clip_index = -1
	drag_grab_offset = 0.0
	drag_start_mouse_position = Vector2.ZERO
	temporary_snap_override_active = false

	_update_cursor_shape()
	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()


func _is_snap_active() -> bool:
	return snap_enabled != temporary_snap_override_active


func _nudge_selected_clip(amount: float, use_snap: bool) -> void:
	if selected_clip_index < 0 or selected_clip_index >= fake_clips.size():
		return

	var clip := fake_clips[selected_clip_index]

	if not clip.has("start") or not clip.has("length"):
		return

	var start: float = clip["start"]
	var length: float = clip["length"]

	var new_start := start + amount

	if use_snap:
		new_start = round(new_start)

	var max_start := max(0.0, float(_get_total_subdivisions()) - length)
	new_start = clamp(new_start, 0.0, max_start)

	clip["start"] = new_start
	fake_clips[selected_clip_index] = clip

	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()


func set_selected_clip_name(value: String) -> void:
	if selected_clip_index < 0 or selected_clip_index >= fake_clips.size():
		return

	var clip := fake_clips[selected_clip_index]
	clip["name"] = value
	fake_clips[selected_clip_index] = clip

	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()

func set_selected_clip_track(value: int) -> void:
	if selected_clip_index < 0 or selected_clip_index >= fake_clips.size():
		return

	var clip := fake_clips[selected_clip_index]
	clip["track"] = clamp(value, 0, track_count - 1)
	fake_clips[selected_clip_index] = clip

	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()

func set_selected_clip_start(value: float) -> void:
	if selected_clip_index < 0 or selected_clip_index >= fake_clips.size():
		return

	var clip := fake_clips[selected_clip_index]

	if not clip.has("length"):
		return

	var length: float = clip["length"]
	var max_start := max(0.0, float(_get_total_subdivisions()) - length)

	clip["start"] = clamp(value, 0.0, max_start)
	fake_clips[selected_clip_index] = clip

	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()

func set_selected_clip_length(value: float) -> void:
	if selected_clip_index < 0 or selected_clip_index >= fake_clips.size():
		return

	var clip := fake_clips[selected_clip_index]

	if not clip.has("start"):
		return

	var start: float = clip["start"]
	var max_length := max(min_clip_length, float(_get_total_subdivisions()) - start)

	clip["length"] = clamp(value, min_clip_length, max_length)
	fake_clips[selected_clip_index] = clip

	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()


func _get_scroll_container() -> ScrollContainer:
	var parent_node := get_parent()

	if parent_node is ScrollContainer:
		return parent_node as ScrollContainer

	return null

func _get_max_horizontal_scroll(scroll_container: ScrollContainer) -> float:
	return max(0.0, _get_total_width() - scroll_container.size.x)

func _set_horizontal_scroll(value: float) -> void:
	var scroll_container := _get_scroll_container()

	if scroll_container == null:
		return

	var max_scroll := _get_max_horizontal_scroll(scroll_container)
	scroll_container.scroll_horizontal = int(clamp(value, 0.0, max_scroll))

func _ensure_rect_visible_horizontally(rect: Rect2, margin: float = 0.0) -> void:
	var scroll_container := _get_scroll_container()

	if scroll_container == null:
		return

	var visible_left := float(scroll_container.scroll_horizontal)
	var visible_right := visible_left + scroll_container.size.x

	var target_scroll := visible_left

	if rect.position.x - margin < visible_left:
		target_scroll = rect.position.x - margin
	elif rect.end.x + margin > visible_right:
		target_scroll = rect.end.x + margin - scroll_container.size.x

	_set_horizontal_scroll(target_scroll)


func _auto_scroll_during_drag(mouse_position: Vector2, delta: float) -> void:
	var scroll_container := _get_scroll_container()

	if scroll_container == null:
		return

	var visible_left := float(scroll_container.scroll_horizontal)
	var visible_right := visible_left + scroll_container.size.x

	var scroll_direction := 0.0
	var strength := 0.0

	if mouse_position.x < visible_left + auto_scroll_edge_threshold:
		var distance_to_edge := (visible_left + auto_scroll_edge_threshold) - mouse_position.x
		strength = clamp(distance_to_edge / auto_scroll_edge_threshold, 0.0, 1.0)
		scroll_direction = -1.0
	elif mouse_position.x > visible_right - auto_scroll_edge_threshold:
		var distance_to_edge := mouse_position.x - (visible_right - auto_scroll_edge_threshold)
		strength = clamp(distance_to_edge / auto_scroll_edge_threshold, 0.0, 1.0)
		scroll_direction = 1.0

	if scroll_direction == 0.0:
		return

	var scroll_amount := auto_scroll_speed * 60.0 * delta
	scroll_amount *= lerp(0.35, 1.0, strength)

	_set_horizontal_scroll(visible_left + (scroll_amount * scroll_direction))

func _get_resize_handle_rect(clip: Dictionary) -> Rect2:
	var clip_rect := _get_clip_rect(clip)
	var handle_width := min(resize_handle_width, clip_rect.size.x)

	return Rect2(
		clip_rect.end.x - handle_width,
		clip_rect.position.y,
		handle_width,
		clip_rect.size.y
	)

func _get_resize_handle_clip_index_at_position(position: Vector2) -> int:
	for i in range(fake_clips.size() - 1, -1, -1):
		var clip := fake_clips[i]

		if not clip.has("track") or not clip.has("start") or not clip.has("length"):
			continue

		var track_index: int = clip["track"]
		var length: float = clip["length"]

		if track_index < 0 or track_index >= track_count:
			continue

		if length <= 0.0:
			continue

		var handle_rect := _get_resize_handle_rect(clip)

		if handle_rect.size.x <= 1.0 or handle_rect.size.y <= 1.0:
			continue

		if handle_rect.has_point(position):
			return i

	return -1

func _update_hovered_resize_handle(position: Vector2) -> void:
	var new_hovered_resize_clip_index := _get_resize_handle_clip_index_at_position(position)

	if new_hovered_resize_clip_index == hovered_resize_clip_index:
		return

	hovered_resize_clip_index = new_hovered_resize_clip_index
	_update_cursor_shape()
	queue_redraw()

func _begin_clip_resize(clip_index: int, mouse_position: Vector2) -> void:
	if clip_index < 0 or clip_index >= fake_clips.size():
		return
	resize_start_mouse_position = mouse_position
	var clip := fake_clips[clip_index]

	if not clip.has("start") or not clip.has("length"):
		return
	var clip_start: float = clip["start"]
	var clip_length: float = clip["length"]
	var clip_end := clip_start + clip_length
	var mouse_timeline_position := _x_to_timeline(mouse_position.x)

	is_resizing_clip = true
	resized_clip_index = clip_index
	resize_grab_offset = mouse_timeline_position - clip_end

	is_dragging_clip = false
	dragged_clip_index = -1
	drag_grab_offset = 0.0

	selected_clip_index = clip_index
	hovered_clip_index = -1
	hovered_resize_clip_index = clip_index
	_update_cursor_shape()
	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()

func _update_clip_resize(mouse_position: Vector2) -> void:
	if not is_resizing_clip:
		return

	if resized_clip_index < 0 or resized_clip_index >= fake_clips.size():
		return

	if mouse_position.distance_to(resize_start_mouse_position) < 4.0:
		return

	var clip := fake_clips[resized_clip_index]

	if not clip.has("start") or not clip.has("length"):
		return

	var start: float = clip["start"]
	var mouse_timeline_position := _x_to_timeline(mouse_position.x)

	var new_end := mouse_timeline_position - resize_grab_offset
	new_end = _snap_timeline_position(new_end)

	var min_end := start + min_clip_length
	var max_end := float(_get_total_subdivisions())
	new_end = clamp(new_end, min_end, max_end)

	var new_length := new_end - start

	clip["length"] = new_length
	fake_clips[resized_clip_index] = clip

	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()


func _end_clip_resize() -> void:
	if not is_resizing_clip:
		return

	is_resizing_clip = false
	resized_clip_index = -1
	resize_grab_offset = 0.0
	resize_start_mouse_position = Vector2.ZERO
	temporary_snap_override_active = false

	_update_cursor_shape()
	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()


func _get_selected_clip_data() -> Dictionary:
	if selected_clip_index < 0 or selected_clip_index >= fake_clips.size():
		return {}

	return fake_clips[selected_clip_index].duplicate(true)

func _emit_selected_clip_changed() -> void:
	selected_clip_changed.emit(selected_clip_index, _get_selected_clip_data())

func clear_selected_clip() -> void:
	if selected_clip_index == -1:
		return

	selected_clip_index = -1
	_emit_status_text()
	_emit_selected_clip_changed()
	queue_redraw()

#Track Editing
func add_track() -> void:
	track_count += 1
	track_names.append(_create_default_track_name(track_count - 1))
	_update_timeline_size()
	_emit_tracks_changed()
	queue_redraw()

func remove_track(track_index: int) -> void:
	if track_count <= 1:
		return
	if track_index < 0 or track_index >= track_count:
		return

	track_names.remove_at(track_index)

	for i in range(fake_clips.size()):
		var clip := fake_clips[i]
		if not clip.has("track"):
			continue

		var clip_track := int(clip["track"])

		if clip_track == track_index:
			clip["track"] = max(0, track_index - 1)
		elif clip_track > track_index:
			clip["track"] = clip_track - 1

		fake_clips[i] = clip

	track_count -= 1

	if selected_clip_index >= 0 and selected_clip_index < fake_clips.size():
		var selected_clip := fake_clips[selected_clip_index]
		if selected_clip.has("track"):
			selected_clip["track"] = clamp(int(selected_clip["track"]), 0, track_count - 1)
			fake_clips[selected_clip_index] = selected_clip

	_update_timeline_size()
	_emit_status_text()
	_emit_selected_clip_changed()
	_emit_tracks_changed()
	queue_redraw()

func rename_track(track_index: int, value: String) -> void:
	if track_index < 0 or track_index >= track_names.size():
		return

	track_names[track_index] = value.strip_edges()
	_emit_tracks_changed()
	queue_redraw()

func move_track(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= track_count:
		return
	if to_index < 0 or to_index >= track_count:
		return
	if from_index == to_index:
		return

	var moved_name := track_names[from_index]
	track_names.remove_at(from_index)
	track_names.insert(to_index, moved_name)

	for i in range(fake_clips.size()):
		var clip := fake_clips[i]
		if not clip.has("track"):
			continue

		var clip_track := int(clip["track"])

		if clip_track == from_index:
			clip["track"] = to_index
		elif from_index < to_index and clip_track > from_index and clip_track <= to_index:
			clip["track"] = clip_track - 1
		elif from_index > to_index and clip_track >= to_index and clip_track < from_index:
			clip["track"] = clip_track + 1

		fake_clips[i] = clip

	_emit_status_text()
	_emit_selected_clip_changed()
	_emit_tracks_changed()
	queue_redraw()


func _create_demo_clips() -> void:
	if not fake_clips.is_empty():
		return

	fake_clips = [
		{
			"track": 0,
			"start": 16.0,
			"length": 12.5,
			"name": "Kick Loop",
			"color": Color(0.25, 0.50, 0.80)
		},
		{
			"track": 0,
			"start": 16.5,
			"length": 15.2,
			"name": "Kick Fill",
			"color": Color(0.25, 0.50, 0.80)
		},
		{
			"track": 1,
			"start": 4.3,
			"length": 6.2,
			"name": "Snare",
			"color": Color(0.80, 0.45, 0.30)
		},
		{
			"track": 1,
			"start": 24.0,
			"length": 8.2,
			"name": "Snare Alt",
			"color": Color(0.78, 0.40, 0.28)
		},
		{
			"track": 2,
			"start": 8.1,
			"length": 16.2,
			"name": "Bass Phrase",
			"color": Color(0.35, 0.75, 0.45)
		},
		{
			"track": 3,
			"start": 32.9,
			"length": 20.5,
			"name": "Melody",
			"color": Color(0.70, 0.40, 0.85)
		}
	]


func _update_temporary_snap_override_from_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion_event := event as InputEventMouseMotion
		temporary_snap_override_active = mouse_motion_event.shift_pressed
	elif event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		temporary_snap_override_active = mouse_button_event.shift_pressed
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		temporary_snap_override_active = key_event.shift_pressed

#Drawing rectangles

func _draw() -> void:
	_draw_background()
	_draw_header()
	_draw_track_lanes()
	_draw_vertical_grid()
	_draw_fake_clips()
	_draw_bar_numbers()

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color, true)

func _draw_header() -> void:
	draw_rect(Rect2(0, 0, size.x, header_height), header_color, true)

	draw_line(
		Vector2(0, header_height),
		Vector2(size.x, header_height),
		header_separator_color,
		1.0
	)

func _draw_track_lanes() -> void:
	for track_index in range(track_count):
		var y := _track_to_y(track_index)
		var color := lane_color_a if track_index % 2 == 0 else lane_color_b

		draw_rect(Rect2(0, y, size.x, lane_height), color, true)

		draw_line(
			Vector2(0, y + lane_height),
			Vector2(size.x, y + lane_height),
			Color(0.0, 0.0, 0.0, 0.35),
			1.0
		)

func _draw_vertical_grid() -> void:
	var total_subdivisions := _get_total_subdivisions()

	for i in range(total_subdivisions + 1):
		var x := i * pixels_per_subdivision

		var color := subdivision_line_color
		var width := 1.0

		if i % (beats_per_bar * subdivisions_per_beat) == 0:
			color = bar_line_color
			width = 2.0
		elif i % subdivisions_per_beat == 0:
			color = beat_line_color

		draw_line(
			Vector2(x, 0),
			Vector2(x, size.y),
			color,
			width
		)

func _draw_bar_numbers() -> void:
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var bar_width := _get_bar_width()

	for bar_index in range(bars):
		var bar_number := str(bar_index + 1)
		var x := (bar_index * bar_width) + 6.0
		var y := header_height * 0.7

		draw_string(
			font,
			Vector2(x, y),
			bar_number,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			bar_number_color
		)



func _draw_fake_clips() -> void:
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()

	for i in range(fake_clips.size()):
		var clip := fake_clips[i]

		if not clip.has("track") or not clip.has("start") or not clip.has("length"):
			continue

		var track_index: int = clip["track"]
		var length: float = clip["length"]

		if track_index < 0 or track_index >= track_count:
			continue

		if length <= 0.0:
			continue

		var rect := _get_clip_rect(clip)

		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue

		var color: Color = clip.get("color", Color(0.35, 0.55, 0.85))

		draw_rect(rect, color, true)

		if i == selected_clip_index:
			draw_rect(rect, selected_clip_overlay_color, true)
			draw_rect(rect, selected_clip_outline_color, false, 2.0)
		elif i == hovered_clip_index:
			draw_rect(rect, hovered_clip_overlay_color, true)
			draw_rect(rect, hovered_clip_outline_color, false, 2.0)
		else:
			draw_rect(rect, clip_outline_color, false, 1.0)

		if i == selected_clip_index or i == hovered_resize_clip_index or i == resized_clip_index:
			var handle_rect := _get_resize_handle_rect(clip)
			var handle_color := active_resize_handle_color if i == resized_clip_index or i == hovered_resize_clip_index else resize_handle_color
			draw_rect(handle_rect, handle_color, true)

		if clip.has("name"):
			var clip_name: String = str(clip["name"])
			var text_position := Vector2(
				rect.position.x + 6.0,
				rect.position.y + (rect.size.y * 0.62)
			)

			draw_string(
				font,
				text_position,
				clip_name,
				HORIZONTAL_ALIGNMENT_LEFT,
				rect.size.x - 10.0,
				font_size,
				clip_text_color
			)

func _update_hovered_clip(position: Vector2) -> void:
	var new_hovered_clip_index := _get_clip_index_at_position(position)

	if new_hovered_clip_index == hovered_clip_index:
		return

	hovered_clip_index = new_hovered_clip_index
	_update_cursor_shape()
	queue_redraw()

func _on_timeline_panel_mouse_exited():
	if is_dragging_clip or is_resizing_clip:
		return

	if hovered_clip_index != -1 or hovered_resize_clip_index != -1:
		hovered_clip_index = -1
		hovered_resize_clip_index = -1
		_update_cursor_shape()
		queue_redraw()
