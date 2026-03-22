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

func _ready() -> void:
	_create_demo_clips()
	_update_timeline_size()
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

func _subdivision_to_x(subdivision: int) -> float:
	return subdivision * pixels_per_subdivision

func _track_to_y(track_index: int) -> float:
	return header_height + (track_index * lane_height)

func _create_demo_clips() -> void:
	if not fake_clips.is_empty():
		return

	fake_clips = [
		{
			"track": 0,
			"start_subdivision": 0,
			"length_subdivisions": 8,
			"name": "Kick Loop",
			"color": Color(0.30, 0.55, 0.85)
		},
		{
			"track": 0,
			"start_subdivision": 16,
			"length_subdivisions": 12,
			"name": "Kick Fill",
			"color": Color(0.25, 0.50, 0.80)
		},
		{
			"track": 1,
			"start_subdivision": 4,
			"length_subdivisions": 6,
			"name": "Snare",
			"color": Color(0.80, 0.45, 0.30)
		},
		{
			"track": 1,
			"start_subdivision": 24,
			"length_subdivisions": 8,
			"name": "Snare Alt",
			"color": Color(0.78, 0.40, 0.28)
		},
		{
			"track": 2,
			"start_subdivision": 8,
			"length_subdivisions": 16,
			"name": "Bass Phrase",
			"color": Color(0.35, 0.75, 0.45)
		},
		{
			"track": 3,
			"start_subdivision": 32,
			"length_subdivisions": 20,
			"name": "Melody",
			"color": Color(0.70, 0.40, 0.85)
		}
	]

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

	for clip in fake_clips:
		if not clip.has("track") or not clip.has("start_subdivision") or not clip.has("length_subdivisions"):
			continue

		var track_index: int = clip["track"]
		var start_subdivision: int = clip["start_subdivision"]
		var length_subdivisions: int = clip["length_subdivisions"]

		if track_index < 0 or track_index >= track_count:
			continue

		if length_subdivisions <= 0:
			continue

		var x := _subdivision_to_x(start_subdivision) + clip_horizontal_padding
		var y := _track_to_y(track_index) + clip_vertical_padding
		var width := (length_subdivisions * pixels_per_subdivision) - (clip_horizontal_padding * 2.0)
		var height := lane_height - (clip_vertical_padding * 2.0)

		if width <= 1.0 or height <= 1.0:
			continue

		var color: Color = clip.get("color", Color(0.35, 0.55, 0.85))
		var rect := Rect2(x, y, width, height)

		draw_rect(rect, color, true)
		draw_rect(rect, clip_outline_color, false, 1.0)

		if clip.has("name"):
			var clip_name: String = str(clip["name"])
			var text_position := Vector2(rect.position.x + 6.0, rect.position.y + (height * 0.62))

			draw_string(
				font,
				text_position,
				clip_name,
				HORIZONTAL_ALIGNMENT_LEFT,
				rect.size.x - 10.0,
				font_size,
				clip_text_color
			)
