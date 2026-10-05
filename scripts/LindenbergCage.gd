extends Control
## Jaula desenhada em camadas: fundo, personagem e grade móvel.

var portrait: TextureRect
var front: Control
var release_target: float = 0.0
var release_amount: float = 0.0
var escape_amount: float = 0.0
var escaped: bool = false


func configure(image: TextureRect, camera_material: ShaderMaterial) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	use_parent_material = false
	material = camera_material
	portrait = image
	portrait.reparent(self, false)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front = Control.new()
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.use_parent_material = true
	add_child(front)
	front.draw.connect(draw_front)


func set_state(charge: float, has_escaped: bool, escape_seconds: float) -> void:
	release_target = clampf(1.0 - charge / 100.0, 0.0, 1.0)
	escaped = has_escaped
	escape_amount = clampf(escape_seconds / 2.5, 0.0, 1.0) if escaped else 0.0
	if escaped:
		release_target = 1.0


func _process(delta: float) -> void:
	if not is_instance_valid(portrait):
		return
	release_amount = move_toward(release_amount, release_target, delta * 0.8)
	# Avança de dentro da jaula até a abertura; rebobinar reverte a pose.
	var emergence: float = smoothstep(0.35, 1.0, release_amount)
	var face_size := Vector2(0.42, 0.39).lerp(Vector2(0.64, 0.59), emergence)
	var face_position := Vector2(0.29, 0.44).lerp(Vector2(0.20, 0.19), emergence)
	face_position += Vector2(0.42, 0.05) * escape_amount
	face_size *= 1.0 + escape_amount * 0.3
	portrait.position = face_position * size
	portrait.size = face_size * size
	portrait.z_index = 1 if emergence > 0.8 else 0
	portrait.self_modulate = Color(1.0, 1.0, 1.0, 1.0 - smoothstep(0.7, 1.0, escape_amount))
	queue_redraw()
	front.queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size)
	# Sombra no chão, interior escuro e laterais em perspectiva.
	draw_ellipse_shadow()
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.16, 0.19), Vector2(0.83, 0.19),
		Vector2(0.83, 0.89), Vector2(0.16, 0.89)
	]), Color(0.055, 0.06, 0.055, 0.96))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.16, 0.19), Vector2(0.25, 0.08),
		Vector2(0.91, 0.08), Vector2(0.83, 0.19)
	]), Color(0.32, 0.33, 0.30))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.83, 0.19), Vector2(0.91, 0.08),
		Vector2(0.91, 0.77), Vector2(0.83, 0.89)
	]), Color(0.13, 0.15, 0.13))
	for i in range(1, 6):
		var x: float = lerpf(0.16, 0.83, float(i) / 6.0)
		draw_line(Vector2(x, 0.19), Vector2(x + 0.08, 0.08), Color(0.48, 0.49, 0.43), 0.012, true)
	for y in [0.27, 0.46, 0.65]:
		draw_line(Vector2(0.83, y + 0.12), Vector2(0.91, y), Color(0.42, 0.44, 0.39), 0.014, true)
	# Base metálica; esconde o corte inferior do busto quando recolhido.
	draw_rect(Rect2(0.12, 0.88, 0.75, 0.07), Color(0.34, 0.35, 0.30))
	draw_line(Vector2(0.12, 0.88), Vector2(0.87, 0.88), Color(0.64, 0.63, 0.53), 0.014, true)


func draw_ellipse_shadow() -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle: float = TAU * float(i) / 32.0
		points.append(Vector2(0.52 + cos(angle) * 0.46, 0.94 + sin(angle) * 0.055))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.55))


func draw_front() -> void:
	front.draw_set_transform(Vector2.ZERO, 0.0, size)
	var metal := Color(0.54, 0.56, 0.49)
	var shine := Color(0.75, 0.73, 0.62)
	# Moldura fixa.
	front.draw_rect(Rect2(0.16, 0.19, 0.67, 0.70), metal, false, 0.024, true)
	# A grade gira para fora ao perder carga no mecanismo.
	var angle: float = smoothstep(0.05, 1.0, release_amount) * PI * 0.48
	var hinge := Vector2(0.16, 0.19)
	var across := Vector2(cos(angle) * 0.67, sin(angle) * 0.15)
	var down := Vector2(0.0, 0.70)
	front.draw_line(hinge, hinge + across, shine, 0.018, true)
	front.draw_line(hinge + down, hinge + across + down, metal, 0.018, true)
	for i in range(7):
		var top: Vector2 = hinge + across * (float(i) / 6.0)
		front.draw_line(top, top + down, metal, 0.018, true)
		front.draw_line(top + Vector2(0.004, 0.0), top + down + Vector2(0.004, 0.0), shine, 0.004, true)
	for fraction in [0.33, 0.67]:
		front.draw_line(hinge + down * fraction, hinge + across + down * fraction, metal, 0.015, true)
	# Trava e manivela acompanham a porta móvel.
	var latch: Vector2 = hinge + across * 0.87 + down * 0.54
	front.draw_rect(Rect2(latch - Vector2(0.035, 0.045), Vector2(0.07, 0.09)), Color(0.44, 0.34, 0.19))
	front.draw_arc(latch, 0.024, 0.0, TAU, 16, shine, 0.007, true)
	var crank_angle: float = release_amount * TAU * 3.0
	front.draw_line(latch, latch + Vector2(cos(crank_angle), sin(crank_angle)) * 0.038, shine, 0.009, true)
