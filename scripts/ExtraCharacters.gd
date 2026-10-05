extends Node
## Lindenberg (noite 2) e Negrelo (noite 3).
## Usa os controles existentes; não modifica a rota do Antônio.

const LINDENBERG_TEXTURE = preload("res://sprites/personagens/lindenberg.png")
const NEGRELO_TEXTURE = preload("res://sprites/personagens/negrelo.png")
const MUSIC_CAMERA: int = 8 # Índice interno: CAM 03.
const CORRIDOR_CAMERA: int = 7 # Índice interno: CAM 02.
const RIGHT_VIEW: int = 2
const LINDENBERG_RECT := Rect2(0.115, 0.435, 0.145, 0.285)
const NEGRELO_CAMERA_RECT := Rect2(0.422, 0.34, 0.075, 0.32)
const NEGRELO_DOOR_RECT := Rect2(0.435, 0.28, 0.075, 0.28)
enum Visit { WAITING, CORRIDOR, DOOR }

var office
var cameras
var manager
var power
var night: int = 1
var configured: bool = false
var stopped: bool = false
var music: float = 100.0
var music_drain: float = 2.5
var winding: bool = false
var escaped: bool = false
var escape_elapsed: float = 0.0
var visit_state: int = Visit.WAITING
var visit_wait: float = 60.0
var visit_elapsed: float = 0.0
var open_elapsed: float = 0.0
var closed_elapsed: float = 0.0
var reaction_time: float = 5.0
var music_panel: PanelContainer
var music_bar: ProgressBar
var wind_button: Button
var warning: Label
var lindenberg_image: TextureRect
var lindenberg_cage
var negrelo_camera: TextureRect
var negrelo_door: TextureRect
var camera_shader: ShaderMaterial
var negrelo_seen: bool = false
var negrelo_unseen_elapsed: float = 0.0


func configure(controller) -> void:
	if configured:
		return
	process_priority = 10 # Verifica a vitória às 06h antes de novos ataques.
	office = controller
	cameras = office.camera_system
	manager = office.get_node("../GameManager")
	power = office.power_system
	night = clampi(int(manager.current_night), 1, 5)
	music_drain = [0.0, 1.2, 2.0, 2.8, 3.6][night - 1]
	reaction_time = [5.0, 5.0, 5.0, 4.5, 4.0][night - 1]
	# O shader é compartilhado apenas entre os dois personagens novos.
	camera_shader = cameras.night_material.duplicate() as ShaderMaterial
	camera_shader.set_shader_parameter("use_mask", false)
	lindenberg_image = make_sprite(cameras.camera_image, LINDENBERG_TEXTURE)
	lindenberg_image.material = camera_shader
	lindenberg_cage = preload("res://scripts/LindenbergCage.gd").new()
	cameras.camera_image.add_child(lindenberg_cage)
	lindenberg_cage.configure(lindenberg_image, camera_shader)
	negrelo_camera = make_sprite(cameras.camera_image, NEGRELO_TEXTURE)
	negrelo_camera.material = camera_shader
	negrelo_door = make_sprite(office.office_image, NEGRELO_TEXTURE)
	negrelo_door.anchor_left = NEGRELO_DOOR_RECT.position.x
	negrelo_door.anchor_top = NEGRELO_DOOR_RECT.position.y
	negrelo_door.anchor_right = NEGRELO_DOOR_RECT.end.x
	negrelo_door.anchor_bottom = NEGRELO_DOOR_RECT.end.y
	create_music_controls()
	schedule_visit()
	configured = true
	refresh_visuals()


func make_sprite(parent: Control, texture: Texture2D) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.use_parent_material = false
	parent.add_child(sprite)
	sprite.hide()
	return sprite


func create_music_controls() -> void:
	music_panel = PanelContainer.new()
	music_panel.z_index = 25
	cameras.panel.add_child(music_panel)
	music_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	music_panel.offset_left = 24.0
	music_panel.offset_top = -146.0
	music_panel.offset_right = 314.0
	music_panel.offset_bottom = -24.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.035, 0.94)
	style.border_color = Color(0.5, 0.6, 0.5)
	style.set_border_width_all(1)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	music_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	music_panel.add_child(column)
	var title := Label.new()
	title.text = "LINDENBERG — TRAVA DA JAULA"
	title.add_theme_font_size_override("font_size", 14)
	column.add_child(title)
	music_bar = ProgressBar.new()
	music_bar.custom_minimum_size = Vector2(260, 22)
	music_bar.value = 100.0
	column.add_child(music_bar)
	wind_button = Button.new()
	wind_button.text = "SEGURE PARA REBOBINAR"
	wind_button.custom_minimum_size = Vector2(260, 36)
	wind_button.focus_mode = Control.FOCUS_NONE
	column.add_child(wind_button)
	wind_button.button_down.connect(func() -> void: winding = true)
	wind_button.button_up.connect(func() -> void: winding = false)
	wind_button.mouse_exited.connect(func() -> void: winding = false)
	warning = Label.new()
	warning.position = Vector2(24, 84)
	warning.z_index = 60
	warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning.add_theme_font_size_override("font_size", 16)
	office.office_image.get_parent().add_child(warning)
	warning.hide()


func _process(delta: float) -> void:
	if not configured or stopped:
		return
	if office.game_over or manager.night_finished or manager.current_hour >= 6:
		stop()
		return
	if power.is_power_out or office.blackout_active:
		stop()
		return
	refresh_visuals()
	# Não pune o jogador enquanto outro susto obriga a mudar de vista.
	if office.window_scare_active or office.ambush_active:
		winding = false
		return
	if night >= 2:
		update_music(delta)
	if office.game_over:
		return
	if night >= 3:
		update_visit(delta)
	refresh_visuals()


func monitor_available() -> bool:
	return (
		cameras.panel.visible
		and power.is_on_cameras
		and not power.is_power_out
		and not cameras.monitor_animation.closing
		and not office.window_scare_active
		and not office.ambush_active
	)


func update_music(delta: float) -> void:
	if escaped:
		escape_elapsed += delta
		if escape_elapsed >= 3.0:
			office.finish_game(false, "lindenberg")
		return
	var can_wind: bool = (
		monitor_available() and cameras.current_camera == MUSIC_CAMERA
		and winding and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and wind_button.get_global_rect().has_point(wind_button.get_global_mouse_position())
	)
	if can_wind:
		music = minf(100.0, music + 24.0 * delta)
	else:
		winding = false
		music = maxf(0.0, music - music_drain * delta)
	if music <= 0.0:
		escaped = true
		winding = false
		escape_elapsed = 0.0


func schedule_visit() -> void:
	var low: Array[float] = [60.0, 60.0, 55.0, 40.0, 28.0]
	var high: Array[float] = [75.0, 75.0, 75.0, 55.0, 42.0]
	visit_wait = randf_range(low[night - 1], high[night - 1])
	visit_state = Visit.WAITING
	visit_elapsed = 0.0
	open_elapsed = 0.0
	closed_elapsed = 0.0
	negrelo_seen = false
	negrelo_unseen_elapsed = 0.0

func update_visit(delta: float) -> void:
	match visit_state:
		Visit.WAITING:
			visit_wait = maxf(0.0, visit_wait - delta)
			if visit_wait <= 0.0 and not cameras.antonio_at_door:
				visit_state = Visit.CORRIDOR
				visit_elapsed = 0.0
		Visit.CORRIDOR:
			visit_elapsed += delta
			if visit_elapsed >= 4.0 and not cameras.antonio_at_door:
				visit_state = Visit.DOOR
				open_elapsed = 0.0
				closed_elapsed = 0.0
		Visit.DOOR:
			if office.door_closed:
				open_elapsed = 0.0
				closed_elapsed += delta

				if closed_elapsed >= 3.0:
					schedule_visit()
				return

			closed_elapsed = 0.0

			var player_sees_negrelo: bool = (
				office.current_view == RIGHT_VIEW
				and not cameras.panel.visible
				and office.flashlight_on
				and not power.is_power_out
			)

			if not negrelo_seen:
				if player_sees_negrelo:
					negrelo_seen = true
					open_elapsed = 0.0
				else:
					negrelo_unseen_elapsed += delta

					if negrelo_unseen_elapsed >= 25.0:
						office.finish_game(false, "negrelo")
				return

			# Depois de visto, desviar o olhar não para a contagem.
			open_elapsed += delta

			if open_elapsed >= 5.0:
				office.finish_game(false, "negrelo")


func refresh_visuals() -> void:
	if stopped:
		return
	var viewing: bool = monitor_available()
	music_panel.visible = night >= 2 and viewing and cameras.current_camera == MUSIC_CAMERA
	if not music_panel.visible:
		winding = false
	wind_button.disabled = escaped or not music_panel.visible
	wind_button.text = "LINDENBERG SAIU!" if escaped else "SEGURE PARA REBOBINAR"
	music_bar.value = music
	music_bar.modulate = Color(1.0, 0.3, 0.25) if music <= 25.0 else Color.WHITE
	warning.visible = night >= 2 and (music <= 25.0 or escaped)
	warning.text = "LINDENBERG SAIU!" if escaped else "JAULA ABRINDO — CAM 03"
	warning.modulate = Color(1.0, 0.35, 0.25)
	lindenberg_cage.visible = night >= 2 and viewing and cameras.current_camera == MUSIC_CAMERA
	lindenberg_image.visible = true
	negrelo_camera.visible = night >= 3 and viewing and cameras.current_camera == CORRIDOR_CAMERA and visit_state == Visit.CORRIDOR
	negrelo_door.visible = (
		night >= 3 and visit_state == Visit.DOOR
		and office.current_view == RIGHT_VIEW and not cameras.panel.visible
		and not office.door_closed and not office.ambush_active
	)
	negrelo_door.self_modulate = (
		Color(0.65, 0.65, 0.65, 1.0)
		if office.flashlight_on and not power.is_power_out
		else Color(0.0, 0.0, 0.0, 0.0)
	)
	var photo: Rect2 = cameras.get_camera_photo_rect()
	lindenberg_cage.position = photo.position + LINDENBERG_RECT.position * photo.size
	lindenberg_cage.size = LINDENBERG_RECT.size * photo.size
	lindenberg_cage.set_state(music, escaped, escape_elapsed)
	place_in_photo(negrelo_camera, NEGRELO_CAMERA_RECT, photo)


func place_in_photo(sprite: TextureRect, area: Rect2, photo: Rect2) -> void:
	sprite.position = photo.position + area.position * photo.size
	sprite.size = area.size * photo.size


func stop() -> void:
	stopped = true
	winding = false
	if configured:
		for item in [music_panel, warning, lindenberg_cage, lindenberg_image, negrelo_camera, negrelo_door]:
			item.hide()
	set_process(false)


func play_jumpscare(character: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.012, 0.015)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var texture: Texture2D = LINDENBERG_TEXTURE if character == "lindenberg" else NEGRELO_TEXTURE
	var face := make_sprite(backdrop, texture)
	face.show()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var height: float = screen.y * (1.35 if character == "lindenberg" else 2.5)
	face.size = Vector2(height * texture.get_width() / texture.get_height(), height)
	var head_uv := Vector2(0.5, 0.38) if character == "lindenberg" else Vector2(0.5, 0.17)
	face.pivot_offset = face.size * head_uv
	face.position = screen * Vector2(0.5, 0.4) - face.pivot_offset
	face.scale = Vector2(0.7, 0.7)
	var initial: Vector2 = face.position
	var tween := create_tween()
	tween.tween_property(face, "scale", Vector2(1.1, 1.1), 0.18)
	for i in range(8):
		tween.tween_property(face, "position", initial + Vector2(randf_range(-8, 8), randf_range(-5, 5)), 0.06)
	tween.tween_interval(0.25)
	await tween.finished
	layer.hide()
	layer.queue_free()
