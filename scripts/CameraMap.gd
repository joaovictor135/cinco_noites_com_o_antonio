extends Control
## Mapa da escola. Os botões mantêm os índices internos das imagens.

var camera_buttons: Array[Button] = []
var night_button: Button

# Ordem visual 01..10 -> índices originais do CameraSystem.
const CAMERA_IDS: Array[int] = [9, 7, 8, 6, 1, 4, 0, 5, 2, 3]
const ROOM_LABELS: Array[String] = [
	"ESCRITÓRIO", "CORR. ESCRIT.", "BIBLIOTECA", "CORR. SALAS",
	"SALA 1", "SALA 2", "SALA 3", "EXTERIOR", "REFEITÓRIO", "PÁTIO"
]
const POINTS: Array[Vector2] = [
	Vector2(180, 320), Vector2(180, 260), Vector2(65, 140),
	Vector2(180, 140), Vector2(65, 200), Vector2(180, 200),
	Vector2(300, 200), Vector2(180, 80), Vector2(300, 80),
	Vector2(180, 20)
]


func configure(system) -> void:
	name = "CameraMap"
	z_index = 30
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -390.0
	offset_top = -420.0
	offset_right = -10.0
	offset_bottom = -10.0
	var canvas := Control.new()
	canvas.name = "MapDrawing"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.position = Vector2(0, 12)
	canvas.draw.connect(func() -> void: draw_floorplan(canvas))
	var group := ButtonGroup.new()
	camera_buttons.resize(10)
	for number in range(10):
		var internal_id: int = CAMERA_IDS[number]
		var button := Button.new()
		button.text = "CAM %02d" % (number + 1)
		button.tooltip_text = button.text
		button.position = POINTS[number] - Vector2(34, 15)
		button.size = Vector2(68, 30)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", box_style(Color(0.16, 0.18, 0.18)))
		button.add_theme_stylebox_override("hover", box_style(Color(0.27, 0.30, 0.25)))
		button.add_theme_stylebox_override("pressed", box_style(Color(0.44, 0.56, 0.08)))
		canvas.add_child(button)
		button.pressed.connect(system.select_camera.bind(internal_id))
		camera_buttons[internal_id] = button
	var you := Label.new()
	you.text = "VOCÊ"
	you.position = Vector2(146, 355)
	you.size = Vector2(68, 20)
	you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	you.add_theme_font_size_override("font_size", 13)
	you.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(you)
	night_button = Button.new()
	night_button.text = "VISÃO NOTURNA: OFF"
	night_button.position = Vector2(12, 385)
	night_button.size = Vector2(228, 30)
	night_button.add_theme_font_size_override("font_size", 12)
	night_button.focus_mode = Control.FOCUS_NONE
	add_child(night_button)
	night_button.pressed.connect(system.toggle_night_vision)
	var close := Button.new()
	close.text = "VOLTAR"
	close.position = Vector2(248, 385)
	close.size = Vector2(120, 30)
	close.focus_mode = Control.FOCUS_NONE
	add_child(close)
	close.pressed.connect(system.close_cameras)
	queue_redraw()


func box_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.92, 0.94, 0.92)
	style.set_border_width_all(2)
	return style


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.66))


func draw_floorplan(canvas: Control) -> void:
	var ink := Color(0.83, 0.87, 0.83, 0.90)

	# Ligações diretas:
	# 10–08, 08–09, 03–04, 04–05, 04–06, 04–07 e 02–01.
	for edge in [
		[9, 7],
		[7, 8],
		[2, 3],
		[3, 4],
		[3, 5],
		[3, 6],
		[1, 0],
		[7, 3],
		[8, 6],
		[6, 1]
	]:
		canvas.draw_line(
			POINTS[edge[0]], POINTS[edge[1]],
			ink, 2.0, true
		)

	# CAM 10 → CAM 09.
	line_path(canvas, [
		POINTS[9],
		Vector2(300, 20),
		POINTS[8]
	], ink)

		# CAM 09 → CAM 04, separado da ligação com a CAM 07.
	canvas.draw_line(
		POINTS[8], POINTS[3],
		ink, 2.0, true
	)

	# CAM 04 → CAM 02, separado das outras ligações.
	line_path(canvas, [
		POINTS[3],
		Vector2(135, 175),
		Vector2(135, 260),
		POINTS[1]
	], ink)

	for point in POINTS:
		canvas.draw_rect(
			Rect2(point - Vector2(38, 19), Vector2(76, 38)),
			ink, false, 1.0
		)

func line_path(canvas: Control, points: Array, color: Color) -> void:
	for i in range(points.size() - 1):
		canvas.draw_line(points[i], points[i + 1], color, 2.0, true)
