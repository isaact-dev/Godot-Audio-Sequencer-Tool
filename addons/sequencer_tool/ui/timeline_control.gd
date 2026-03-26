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

var selected_clip_index: int = -1
var hovered_clip_index: int = -1

var selected_clip_outline_color := Color(1.0, 0.9, 0.35, 1.0)
var selected_clip_overlay_color := Color(1.0, 1.0, 1.0, 0.08)
var hovered_clip_outline_color := Color(1.0, 1.0, 1.0, 0.38)
var hovered_clip_overlay_color := Color(1.0, 1.0, 1.0, 0.05)

var is_dragging_clip: bool = false
var dragged_clip_index: int = -1
var drag_grab_offset: float = 0.0
var temporary_snap_override_active: bool = false

signal status_text_changed(text: String)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

	_create_demo_clips()
	_update_timeline_size()
	call_deferred("_emit_status_text")
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
	_update_timeline_size()
	queue_redraw()

func _timeline_to_x(position: float) -> float:
	return position * pixels_per_subdivision

func _x_to_timeline(x: float) -> float:
	return x / pixels_per_subdivision

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

	return "Selected: %s | Start: %.2f | Length: %.2f | Snap: %s" % [
		clip_name,
		start,
		length,
		snap_text
	]

func _emit_status_text() -> void:
	status_text_changed.emit(_build_status_text())


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

		if is_dragging_clip:
			_update_clip_drag(mouse_motion_event.position)
		else:
			_update_hovered_clip(mouse_motion_event.position)

		return

	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton

		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button_event.pressed:
				grab_focus()

				var clicked_clip_index := _get_clip_index_at_position(mouse_button_event.position)

				selected_clip_index = clicked_clip_index
				_emit_status_text()
				if clicked_clip_index != -1:
					_begin_clip_drag(clicked_clip_index, mouse_button_event.position)
				else:
					queue_redraw()
			else:
				_end_clip_drag()
				_update_hovered_clip(mouse_button_event.position)


#Dragging

func _snap_timeline_position(position: float) -> float:
	if not _is_snap_active():
		return position

	return round(position)

func _update_cursor_shape() -> void:
	if is_dragging_clip:
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	elif hovered_clip_index != -1:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _begin_clip_drag(clip_index: int, mouse_position: Vector2) -> void:
	if clip_index < 0 or clip_index >= fake_clips.size():
		return

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
	_ensure_selected_clip_visible()
	queue_redraw()


func _update_clip_drag(mouse_position: Vector2) -> void:
	if not is_dragging_clip:
		return

	if dragged_clip_index < 0 or dragged_clip_index >= fake_clips.size():
		return

	var clip := fake_clips[dragged_clip_index]

	if not clip.has("start") or not clip.has("length"):
		return

	var length: float = clip["length"]
	var mouse_timeline_position := _x_to_timeline(mouse_position.x)

	var new_start := mouse_timeline_position - drag_grab_offset
	new_start = _snap_timeline_position(new_start)

	var max_start := max(0.0, float(_get_total_subdivisions()) - length)
	new_start = clamp(new_start, 0.0, max_start)

	clip["start"] = new_start
	fake_clips[dragged_clip_index] = clip

	_auto_scroll_during_drag(mouse_position)
	_emit_status_text()
	queue_redraw()



func _end_clip_drag() -> void:
	if not is_dragging_clip:
		return

	is_dragging_clip = false
	dragged_clip_index = -1
	drag_grab_offset = 0.0
	temporary_snap_override_active = false

	_update_cursor_shape()
	_emit_status_text()
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

	_ensure_selected_clip_visible()
	_emit_status_text()
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

func _ensure_selected_clip_visible() -> void:
	if selected_clip_index < 0 or selected_clip_index >= fake_clips.size():
		return

	var clip := fake_clips[selected_clip_index]

	if not clip.has("track") or not clip.has("start") or not clip.has("length"):
		return

	var rect := _get_clip_rect(clip)

	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return

	_ensure_rect_visible_horizontally(rect, visible_scroll_margin)

func _auto_scroll_during_drag(mouse_position: Vector2) -> void:
	var scroll_container := _get_scroll_container()

	if scroll_container == null:
		return

	var visible_left := float(scroll_container.scroll_horizontal)
	var visible_right := visible_left + scroll_container.size.x

	if mouse_position.x < visible_left + auto_scroll_edge_threshold:
		_set_horizontal_scroll(visible_left - auto_scroll_speed)
	elif mouse_position.x > visible_right - auto_scroll_edge_threshold:
		_set_horizontal_scroll(visible_left + auto_scroll_speed)


func _create_demo_clips() -> void:
	if not fake_clips.is_empty():
		return

	fake_clips = [
		{
			"track": 0,
			"start": 16.0,
			"length": 12.5,
			"name": "Kick Loop",
			"color": Color(0.30, 0.55, 0.85)
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
	if is_dragging_clip:
		return

	if hovered_clip_index != -1:
		hovered_clip_index = -1
		_update_cursor_shape()
		queue_redraw()
