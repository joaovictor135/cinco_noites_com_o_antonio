extends Node
@onready var power_system = $"../PowerSystem"
@onready var panel = $"../../UI/CameraPanel"
@onready var camera_image = $"../../UI/CameraPanel/CameraImage"
@onready var camera_name = $"../../UI/CameraPanel/CameraName"
@onready var buttons = $"../../UI/CameraPanel/CameraButtons"
@onready var night_button = buttons.get_node("NightVisionButton")
@onready var antonio_image = $"../../UI/CameraPanel/CameraImage/AntonioImage"
@onready var furniture_overlay = $"../../UI/CameraPanel/CameraImage/FurnitureOverlay"
# A câmera traseira monitora a emboscada do OfficeController.
const REAR_CAMERA_INDEX: int = 9
var rear_curtain_open: bool = false
var rear_antonio_present: bool = false
var rear_open_texture: Texture2D = preload("res://sprites/cameras/camera_atras_aberta.png")
var rear_closed_texture: Texture2D = preload("res://sprites/cameras/camera_atras_fechada.png")
var antonio_back: Texture2D = preload("res://sprites/antonio/antonio_costas.png")

var current_camera: int = 3
var night_vision_on: bool = false
var night_material: ShaderMaterial
var antonio_material: ShaderMaterial
var furniture_material: ShaderMaterial
var table_mask: Texture2D
var antonio_camera: int = 3
var antonio_spot: int = 0
var movement_elapsed: float = 0.0
var movement_interval: float = 8.0
var camera_textures: Array[Texture2D] = [
	preload("res://sprites/cameras/biblioteca.png"),
	preload("res://sprites/cameras/sala_de_aula01.png"),
	preload("res://sprites/cameras/refeitorio.png"),
	preload("res://sprites/cameras/lado_exterior02.png"),
	preload("res://sprites/cameras/sala_de_aula02.png"),
	preload("res://sprites/cameras/lado_exterior01.png"),
	preload("res://sprites/cameras/corredor_salas.png"),
	preload("res://sprites/cameras/office_corredor.png"),
	# A sala antiga continua como terceira sala.
	preload("res://sprites/cameras/sala_de_aula.png"),
	preload("res://sprites/cameras/camera_atras_fechada.png")
]

# Biblioteca, refeitório e sala 3: coordenadas antigas (base 1152 x 648).
# As câmeras novas usam frações do retângulo realmente desenhado da foto.
# Rect2(x, y, largura, altura). Ajuste fino após conferir no jogo.
var antonio_spots: Array = [
	[Rect2(500, 430, 110, 120), Rect2(600, 220, 55, 110), Rect2(370, 100, 400, 760)],
	# Sala 1: ao lado direito da TV, mais abaixo.
	[Rect2(0.25, 0.49, 0.08, 0.29)],
	[Rect2(140, 135, 65, 125), Rect2(190, 470, 115, 125)],
	# Pátio: banco vermelho próximo, na área marcada; levanta a cabeça antes de sair.
	[Rect2(0.58, 0.48, 0.10, 0.28)],
	# Sala 2: dois closes, evitando sobreposição incorreta com as carteiras.
	[Rect2(0.20, 0.64, 0.22, 0.76), Rect2(0.64, 0.64, 0.22, 0.76)],
	# Passagem externa: perto ou longe no caminho.
	[Rect2(0.195, 0.31, 0.15, 0.48), Rect2(0.489, 0.322, 0.088, 0.368)],
	# Corredor das salas: uma posição bem ao fundo.
	[Rect2(0.48, 0.38, 0.028, 0.12)],
	# Corredor do escritório: no espaço livre à direita das cadeiras.
	[Rect2(0.475, 0.41, 0.04, 0.15), Rect2(0.515, 0.56, 0.065, 0.25)],
	[Rect2(855, 245, 170, 72), Rect2(76, 430, 1000, 2000)]
]
var camera_buttons: Array[Button] = []
var navigation: Control
var camera_names: Array[String] = [
	"CAM 07 - BIBLIOTECA",
	"CAM 05 - SALA DE AULA 1",
	"CAM 09 - REFEITÓRIO",
	"CAM 10 - PÁTIO",
	"CAM 06 - SALA DE AULA 2",
	"CAM 08 - PASSAGEM EXTERIOR",
	"CAM 04 - CORREDOR DAS SALAS",
	"CAM 02 - CORREDOR DO ESCRITÓRIO",
	"CAM 03 - SALA DE AULA 3",
	"CAM 01 - ATRÁS DO JOGADOR"
]
var antonio_standing: Texture2D = preload(
	"res://sprites/antonio/antonio.png"
)
var antonio_crouching: Texture2D = preload(
	"res://sprites/antonio/Antonio_agachado.png"
)
var antonio_peeking: Texture2D = preload(
	"res://sprites/antonio/antonio_espiando.png"
)
var antonio_lying: Texture2D = preload(
	"res://sprites/antonio/antonio_deitado.png"
)
var shelves_mask: Texture2D = preload(
	"res://sprites/cameras/biblioteca_estantes_mask.png"
)
var cafeteria_door_mask: Texture2D = preload(
	"res://sprites/cameras/refeitorio_porta_mask.png"
)
var cafeteria_table_mask: Texture2D = preload(
	"res://sprites/cameras/refeitorio_mesa_mask.png"
)
var antonio_sitting: Texture2D = preload(
	"res://sprites/antonio/antonio_sentado.png"
)
var antonio_sitting_head_down: Texture2D = preload(
	"res://sprites/antonio/antonio_sentado_cabeca_baixa.png"
)
var patio_head_up: bool = false
var patio_standing: bool = false
var patio_head_up_duration: float = 2.0
signal antonio_arrived_at_door

# Percurso provisório, termina no corredor do escritório. Uma posição por visita.
var antonio_route: Array[int] = [3, 5, 0, 2, 4, 8, 1, 6, 7]
var route_step: int = 0
var antonio_at_door: bool = false

var antonio_waiting_at_window: bool = false

var monitor_animation
var antonio_start_hour: int = 0
var corridor_window_scare_used: bool = false

const SOUND_DELAY: float = 3.0
const SOUND_COOLDOWN: float = 20.0

var sound_button: Button
var sound_target: int = -1
var sound_remaining: float = 0.0
var sound_cooldown: float = 0.0
var sound_patio_visit: bool = false


func _ready() -> void:
	monitor_animation = preload("res://scripts/CameraMonitorAnimation.gd").new()
	add_child(monitor_animation)
	monitor_animation.configure(panel)
	panel.hide()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	camera_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_image.clip_contents = true
	camera_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camera_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	camera_image.resized.connect(update_antonio)
	antonio_image.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	antonio_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	antonio_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	antonio_image.scale = Vector2.ONE
	antonio_image.modulate = Color(0.12, 0.14, 0.17, 1.0)
	antonio_image.self_modulate = Color.WHITE
	antonio_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	antonio_image.use_parent_material = false
	create_night_vision()
	antonio_material = ShaderMaterial.new()
	antonio_material.shader = night_material.shader
	antonio_material.set_shader_parameter("brightness", 0.85)
	antonio_image.material = antonio_material
	setup_furniture_overlay()
		# Escurece apenas o cenário e os recortes dos móveis.
	night_material.set_shader_parameter("camera_darkness", 0.25)
	furniture_material.set_shader_parameter("camera_darkness", 0.25)
	setup_camera_buttons()
	power_system.power_out.connect(close_cameras)
	# CAM 02 — Sala 1: ao lado direito da TV.
	antonio_spots[1] = [
		Rect2(0.25, 0.49, 0.08, 0.29)
	]
	# CAM 05 — Sala 2: maior, na mesma região da direita.
	antonio_spots[4] = [
		Rect2(0.585, 0.34, 0.33, 1.14)
	]
	# CAM 06 — Exterior: nas duas marcações.
	antonio_spots[5] = [
		Rect2(0.195, 0.31, 0.15, 0.48),
		Rect2(0.489, 0.322, 0.088, 0.368)
	]
		# CAM 07 — Corredor das salas.
	antonio_spots[6] = [
		# Posição existente ao fundo.
		Rect2(0.483, 0.53, 0.042, 0.18),

		# Nova posição próxima, à direita.
		Rect2(0.755, 0.38, 0.19, 0.53)
	]
	# CAM 08 — Corredor do escritório: na marcação.
	antonio_spots[7] = [
		Rect2(0.468, 0.43, 0.056, 0.21)
	]

	choose_antonio_spot()
	close_cameras()
	select_camera(current_camera)
	generate_random_route()
	
	var window_mask = preload("res://scripts/WindowOccluder.gd").new()
	window_mask.configure(
		camera_image,
		antonio_image,
		true,
		func() -> bool:
			return (
				current_camera == REAR_CAMERA_INDEX
				and antonio_waiting_at_window
				and rear_curtain_open
			)
	)
	
	var interference = preload("res://scripts/CameraInterference.gd").new()
	interference.configure(self, camera_image, panel)
	
	create_sound_button()


func setup_furniture_overlay() -> void:
	# Guarda a máscara da mesa da biblioteca definida no Inspetor.
	table_mask = furniture_overlay.texture
	if table_mask == null:
		push_warning(
			"FurnitureOverlay está sem a máscara da mesa da biblioteca."
		)
	furniture_material = ShaderMaterial.new()
	furniture_material.shader = night_material.shader
	furniture_material.set_shader_parameter("use_mask", true)
	if table_mask != null:
		furniture_material.set_shader_parameter(
			"furniture_mask", table_mask
		)
	# As cores vêm do cenário; a máscara fornece a transparência.
	furniture_overlay.texture = camera_textures[current_camera]
	furniture_overlay.use_parent_material = false
	furniture_overlay.material = furniture_material
	furniture_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	furniture_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	furniture_overlay.stretch_mode = camera_image.stretch_mode
	furniture_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	furniture_overlay.scale = Vector2.ONE
	furniture_overlay.rotation = 0.0
	furniture_overlay.modulate = Color.WHITE
	furniture_overlay.self_modulate = Color.WHITE
	furniture_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	furniture_overlay.hide()


func create_night_vision() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform bool enabled = false;
uniform float brightness = 1.6;
uniform float camera_darkness = 1.0;

uniform bool use_mask = false;
uniform sampler2D furniture_mask : filter_linear, repeat_disable;
uniform bool open_shelf_gap = false;

void fragment() {
	vec4 original = COLOR;
	if (use_mask) {
		float mask_alpha = texture(furniture_mask, UV).a;
		if (open_shelf_gap) {
			bool inside_gap = (
				UV.x > 0.55 && UV.x < 0.59 &&
				UV.y > 0.34 && UV.y < 0.43
			);
			if (inside_gap) {
				mask_alpha = 0.0;
			}
		}
		original.a *= mask_alpha;
	}
	if (enabled) {
		float gray = dot(original.rgb, vec3(0.299, 0.587, 0.114));
		float light_value = pow(max(gray, 0.0), 0.45);
		light_value = clamp(light_value * brightness, 0.0, 1.0);
		vec3 green = vec3(0.22, 1.0, 0.32) * light_value;
		COLOR = vec4(green, original.a);
	} else {
		COLOR = vec4(original.rgb * camera_darkness, original.a);
	}
}
"""
	night_material = ShaderMaterial.new()
	night_material.shader = shader
	camera_image.use_parent_material = false
	camera_image.material = night_material
	camera_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func select_camera(index: int) -> void:
	if index < 0 or index >= camera_textures.size():
		return
	current_camera = index
	var selected_texture: Texture2D = camera_textures[index]
	if index == REAR_CAMERA_INDEX:
		selected_texture = rear_open_texture if rear_curtain_open else rear_closed_texture
	camera_image.texture = selected_texture
	furniture_overlay.texture = selected_texture
	camera_name.text = camera_names[index]
	update_antonio()
	for i in range(camera_buttons.size()):
		camera_buttons[i].set_pressed_no_signal(i == current_camera)


func open_cameras() -> void:
	if power_system.is_power_out:
		return

	if panel.visible and not monitor_animation.closing:
		return

	select_camera(current_camera)
	power_system.set_cameras(true)
	monitor_animation.open_monitor()


func close_cameras(immediate: bool = false) -> void:
	set_night_vision(false)
	power_system.set_cameras(false)

	monitor_animation.close_monitor(
		immediate or power_system.is_power_out
	)


func toggle_night_vision() -> void:
	if power_system.is_power_out or not panel.visible:
		return
	set_night_vision(not night_vision_on)
	# CAM 02 — Sala 1: ao lado direito da TV.
	antonio_spots[1] = [
		Rect2(0.25, 0.49, 0.08, 0.29)
	]
	# CAM 05 — Sala 2: maior, na mesma região da direita.
	antonio_spots[4] = [
		Rect2(0.585, 0.34, 0.33, 1.14)
	]
	# CAM 06 — Exterior: nas duas marcações.
	antonio_spots[5] = [
		# Marca da esquerda, perto do muro.
		Rect2(0.195, 0.31, 0.15, 0.48),
		# Marca ao fundo, na calçada.
		Rect2(0.489, 0.322, 0.088, 0.368)
	]


func set_night_vision(active: bool) -> void:
	night_vision_on = (
		active and panel.visible and not power_system.is_power_out
	)

	night_material.set_shader_parameter("enabled", night_vision_on)
	antonio_material.set_shader_parameter("enabled", night_vision_on)
	furniture_material.set_shader_parameter("enabled", night_vision_on)
	power_system.set_night_vision(night_vision_on)

	if night_vision_on:
		# Remove o escurecimento para receber o mesmo filtro do cenário.
		antonio_image.modulate = Color.WHITE
		night_button.text = "VISÃO NOTURNA: ON"
	else:
		# Recupera a aparência escura quando a visão noturna desliga.
		antonio_image.modulate = Color(0.12, 0.14, 0.17, 1.0)
		night_button.text = "VISÃO NOTURNA: OFF"
		
	update_antonio_shadows()


func choose_antonio_spot() -> void:
	# Uma posição aleatória por visita à sala.
	var spots: Array = antonio_spots[antonio_camera]
	antonio_spot = randi_range(0, spots.size() - 1)


func show_furniture_mask(
	mask_texture: Texture2D,
	open_gap: bool = false ) -> void:
	if mask_texture == null:
		furniture_overlay.hide()
		return
	furniture_material.set_shader_parameter(
		"furniture_mask", mask_texture
	)
	furniture_material.set_shader_parameter(
		"open_shelf_gap", open_gap
	)
	furniture_overlay.show()


func update_antonio() -> void:
	if furniture_material == null:
		return
	furniture_overlay.hide()
	furniture_material.set_shader_parameter("open_shelf_gap", false)
	if current_camera == REAR_CAMERA_INDEX:
		update_rear_antonio()
		return
	antonio_image.visible = (
		not antonio_at_door
		and not antonio_waiting_at_window
		and current_camera == antonio_camera
	)
	if not antonio_image.visible:
		return
	var spot: Rect2 = antonio_spots[antonio_camera][antonio_spot]
	update_antonio_shadows()
	# Pose padrão para os pontos sem pose especial.
	antonio_image.texture = antonio_standing
	if antonio_camera == 0:
		match antonio_spot:
			0:
				antonio_image.texture = antonio_crouching
				show_furniture_mask(table_mask)
			1:
				antonio_image.texture = antonio_peeking
				show_furniture_mask(shelves_mask, true)
			2:
				# Em pé, perto da câmera.
				pass
	elif antonio_camera == 8:
		match antonio_spot:
			0:
				antonio_image.texture = antonio_lying
			1:
				# Close usando a pose normal.
				pass
	elif antonio_camera == 2:
		match antonio_spot:
			0:
				# Antônio aparece à frente da porta.
				furniture_overlay.hide()
			1:
				antonio_image.texture = antonio_crouching
				show_furniture_mask(cafeteria_table_mask)

	elif antonio_camera == 3:
		if patio_standing:
			antonio_image.texture = antonio_standing
			spot = Rect2(0.58, 0.43, 0.10, 0.34)
		else:
			# Sentado no banco vermelho ao fundo.
			spot = Rect2(0.22, 0.515, 0.045, 0.095)
			if patio_head_up:
				antonio_image.texture = antonio_sitting
			else:
				antonio_image.texture = antonio_sitting_head_down
	if antonio_camera in [0, 2, 8]:
		# Mantém os ajustes existentes das imagens antigas.
		var legacy_scale: Vector2 = camera_image.size / Vector2(1152.0, 648.0)
		antonio_image.size = spot.size * legacy_scale
		antonio_image.position = spot.position * legacy_scale
	else:
		var photo_rect: Rect2 = get_camera_photo_rect()
		antonio_image.size = spot.size * photo_rect.size
		antonio_image.position = photo_rect.position + spot.position * photo_rect.size


func _process(delta: float) -> void:
	if update_sound_lure(delta):
		return
	if $"../GameManager".current_hour < antonio_start_hour:
		movement_elapsed = 0.0
		return
	if power_system.is_power_out or antonio_at_door:
		return
	if movement_interval <= 0.0:
		return
	if antonio_waiting_at_window:
		return
	movement_elapsed += delta
	if antonio_camera == 3 and not sound_patio_visit:
		# Primeiro: sentado com a cabeça abaixada.
		if not patio_head_up:
			if movement_elapsed >= movement_interval:
				movement_elapsed = 0.0
				patio_head_up = true
				update_antonio()
			return
		# Segundo: permanece sentado, com a cabeça levantada.
		if not patio_standing:
			if movement_elapsed >= patio_head_up_duration:
				movement_elapsed = 0.0
				patio_standing = true
				update_antonio()
			return
		# Terceiro: fica em pé por 2 segundos antes de sair.
				# Depois do pátio, espera na janela.
		if movement_elapsed < 2.0:
			return

	elif movement_elapsed < movement_interval:
		return

	# Índice interno 7 = CAM 02, corredor do escritório.
	if antonio_camera == 7 and not corridor_window_scare_used:
		corridor_window_scare_used = true

		if randf() < 0.5:
			movement_elapsed = 0.0
			antonio_waiting_at_window = true
			update_antonio()
			$"../OfficeController".start_window_scare()
			return

	movement_elapsed = 0.0
	patio_head_up = false
	# CAM 02 — Sala 1: ao lado direito da TV.
	antonio_spots[1] = [
		Rect2(0.25, 0.49, 0.08, 0.29)
	]
	# CAM 05 — Sala 2: maior, na mesma região da direita.
	antonio_spots[4] = [
		Rect2(0.585, 0.34, 0.33, 1.14)
	]
	# CAM 06 — Exterior: nas duas marcações.
	antonio_spots[5] = [
		# Marca da esquerda, perto do muro.
		Rect2(0.195, 0.31, 0.15, 0.48),
		# Marca ao fundo, na calçada.
		Rect2(0.489, 0.322, 0.088, 0.368)
	]
	route_step += 1
	# Depois do corredor do escritório, chega à porta.
	if route_step >= antonio_route.size():
		antonio_at_door = true
		antonio_camera = -1
		update_antonio()
		antonio_arrived_at_door.emit()
		print("Antonio chegou à porta do escritório!")
		return
	# Segue o percurso e escolhe uma posição nessa sala.
	antonio_camera = antonio_route[route_step]
	choose_antonio_spot()
	update_antonio()
	print(
		"Antonio está em: ",
		camera_names[antonio_camera],
		" | Posição: ",
		antonio_spot + 1
	)



func reset_antonio_to_patio() -> void:
	sound_patio_visit = false
	generate_random_route()
	route_step = 0
	antonio_at_door = false
	antonio_camera = antonio_route[0]
	movement_elapsed = 0.0
	patio_head_up = false
	patio_standing = false
	choose_antonio_spot()
	update_antonio()
	corridor_window_scare_used = false


func get_camera_photo_rect() -> Rect2:
	var texture_size: Vector2 = camera_image.texture.get_size()
	var available: Vector2 = camera_image.size
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(Vector2.ZERO, available)
	var factor: float = minf(available.x / texture_size.x, available.y / texture_size.y)
	var drawn: Vector2 = texture_size * factor
	return Rect2((available - drawn) * 0.5, drawn)


func setup_camera_buttons() -> void:
	buttons.hide()
	camera_buttons.clear()

	var camera_map = preload("res://scripts/CameraMap.gd").new()
	panel.add_child(camera_map)
	camera_map.configure(self)

	navigation = camera_map
	camera_buttons = camera_map.camera_buttons
	night_button = camera_map.night_button

func style_camera_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.03, 0.035, 0.9)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	button.add_theme_stylebox_override("normal", normal)
	var selected: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	selected.bg_color = Color(0.12, 0.25, 0.16, 0.95)
	button.add_theme_stylebox_override("pressed", selected)
	var hovered: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hovered.bg_color = Color(0.15, 0.18, 0.2, 0.95)
	button.add_theme_stylebox_override("hover", hovered)
	button.add_theme_stylebox_override("hover_pressed", selected)
	
func update_antonio_shadows() -> void:
	if night_vision_on:
		antonio_image.modulate = Color.WHITE
		return

	if current_camera == REAR_CAMERA_INDEX:
		antonio_image.modulate = Color(0.05, 0.06, 0.075, 1.0)
		return

	match antonio_camera:
		0: # Biblioteca.
			if antonio_spot == 2: # Posição 3: mantém a cor atual.
				antonio_image.modulate = Color(0.12, 0.14, 0.17, 1.0)
			else: # Posições 1 e 2: mais escuras.
				antonio_image.modulate = Color(0.05, 0.06, 0.075, 1.0)
		1, 2, 3, 4, 5, 8: # Salas 1, 2 e 3, refeitório, pátio e exterior.
			antonio_image.modulate = Color(0.05, 0.06, 0.075, 1.0)
		6, 7: # Corredores: sombras mais fortes.
			antonio_image.modulate = Color(0.025, 0.03, 0.04, 1.0)
		_:
			antonio_image.modulate = Color(0.12, 0.14, 0.17, 1.0)


func set_rear_view_state(curtain_is_open: bool, antonio_is_present: bool) -> void:
	rear_curtain_open = curtain_is_open
	rear_antonio_present = antonio_is_present
	if current_camera == REAR_CAMERA_INDEX and night_material != null:
		select_camera(current_camera)


func update_rear_antonio() -> void:
	antonio_image.visible = (
		rear_antonio_present
		and (not antonio_waiting_at_window or rear_curtain_open)
	)

	if not antonio_image.visible:
		return

	var spot: Rect2

	if antonio_waiting_at_window:
		# Cabeça e tronco vistos pela janela da câmera 10.
		var upper_body := AtlasTexture.new()
		upper_body.atlas = antonio_standing
		var original_size: Vector2 = antonio_standing.get_size()
		upper_body.region = Rect2(
			0.0, 0.0,
			original_size.x, original_size.y * 0.48
		)
		upper_body.filter_clip = true
		antonio_image.texture = upper_body
		spot = Rect2(0.316, 0.335, 0.108, 0.234)
	else:
		# Dentro do escritório, continua de costas.
		antonio_image.texture = antonio_back
		spot = Rect2(0.36, 0.25, 0.24, 0.65)

	update_antonio_shadows()

	var photo_rect: Rect2 = get_camera_photo_rect()
	antonio_image.size = spot.size * photo_rect.size
	antonio_image.position = (
		photo_rect.position + spot.position * photo_rect.size
	)
	
func generate_random_route(start_camera: int = 3) -> void:
	# Índices internos, não os números exibidos.
	var connections: Dictionary = {
		5: [2, 6],
		0: [6, 2, 7],
		2: [5, 6, 0],
		6: [0, 2, 1, 4, 8, 5],
		1: [6],
		4: [6],
		8: [6]
	}

	antonio_route = [start_camera]
	# Se o som trouxe Antônio ao corredor, a próxima saída é o ataque.
	if start_camera == 7:
		return

	var previous_room: int = -1
	var room: int = start_camera

	if start_camera == 3:
		previous_room = 3
		room = int([2, 5].pick_random())
		antonio_route.append(room)

	var night: int = clampi($"../GameManager".current_night, 1, 5)
	var minimum_steps: Array[int] = [6, 5, 4, 3, 2]
	var maximum_steps: Array[int] = [8, 7, 6, 4, 3]

	var random_steps: int = randi_range(
		minimum_steps[night - 1],
		maximum_steps[night - 1]
	)

	for i in range(random_steps):
		var options: Array = connections[room].duplicate()

		# Evita voltar imediatamente quando há outra saída.
		# Nas salas, permite retornar pelo corredor.
		if options.size() > 1:
			options.erase(previous_room)

		var next_room: int = int(options.pick_random())
		previous_room = room
		room = next_room
		antonio_route.append(room)

		# Já chegou ao corredor do escritório.
		if room == 7:
			break

	# Encerra a rota quando chegou pela biblioteca.
	if room == 7:
		return

	# Do exterior, sai pelo refeitório.
	if room == 5:
		room = 2
		antonio_route.append(room)

	# Passa pelo corredor das salas antes do escritório.
	if room != 6:
		antonio_route.append(6)

	antonio_route.append(7)

func return_to_random_camera() -> void:
	# Biblioteca, salas, refeitório, exterior ou corredor das salas.
	var destinations: Array[int] = [0, 1, 2, 4, 5, 6, 8]
	var destination: int = int(destinations.pick_random())

	generate_random_route(destination)
	route_step = 0
	antonio_camera = destination
	antonio_at_door = false
	antonio_waiting_at_window = false
	corridor_window_scare_used = false
	movement_elapsed = 0.0
	patio_head_up = false
	patio_standing = false

	choose_antonio_spot()
	update_antonio()
	
func create_sound_button() -> void:
	sound_button = Button.new()
	panel.add_child(sound_button)
	sound_button.position = Vector2(24, 130)
	sound_button.size = Vector2(230, 40)
	sound_button.z_index = 30
	sound_button.focus_mode = Control.FOCUS_NONE
	style_camera_button(sound_button)
	sound_button.pressed.connect(play_sound_lure)
	refresh_sound_button()


func can_attract_antonio() -> bool:
	var office = $"../OfficeController"
	var manager = $"../GameManager"

	return (
		not office.game_over
		and not manager.night_finished
		and manager.current_hour < 6
		and manager.current_hour >= antonio_start_hour
		and not power_system.is_power_out
		and not antonio_at_door
		and not antonio_waiting_at_window
		and not office.window_scare_active
		and not office.ambush_active
		and antonio_camera >= 0
		and antonio_camera < REAR_CAMERA_INDEX
	)


func play_sound_lure() -> void:
	if sound_target != -1 or sound_cooldown > 0.0:
		return
	if not panel.visible or monitor_animation.closing:
		return
	if current_camera == REAR_CAMERA_INDEX:
		return
	if not can_attract_antonio():
		return

	# Guarda a câmera escolhida, mesmo se o jogador trocar depois.
	sound_target = current_camera
	sound_remaining = SOUND_DELAY
	sound_cooldown = SOUND_COOLDOWN
	refresh_sound_button()


func update_sound_lure(delta: float) -> bool:
	sound_cooldown = maxf(0.0, sound_cooldown - delta)
	var teleported: bool = false

	if sound_target != -1:
		# Não interrompe um ataque que começou durante a espera.
		if not can_attract_antonio():
			sound_target = -1
			sound_remaining = 0.0
		else:
			sound_remaining = maxf(0.0, sound_remaining - delta)

			if sound_remaining <= 0.0:
				var destination: int = sound_target
				sound_target = -1

				if randf() < 0.70:
					teleport_antonio_to_sound(destination)
					teleported = true
				# Se ignorar, mantém o percurso e o tempo atuais.

	refresh_sound_button()
	return teleported


func teleport_antonio_to_sound(destination: int) -> void:
	generate_random_route(destination)
	route_step = 0
	antonio_camera = destination
	movement_elapsed = 0.0
	corridor_window_scare_used = false

	# No pátio, já aparece em pé e espera o intervalo da noite.
	sound_patio_visit = destination == 3
	patio_head_up = sound_patio_visit
	patio_standing = sound_patio_visit

	choose_antonio_spot()
	update_antonio()


func refresh_sound_button() -> void:
	if not is_instance_valid(sound_button):
		return

	sound_button.disabled = (
		sound_target != -1
		or sound_cooldown > 0.0
		or current_camera == REAR_CAMERA_INDEX
		or not can_attract_antonio()
		or not panel.visible
		or monitor_animation.closing
	)

	if sound_target != -1:
		sound_button.text = "TRANSMITINDO... %ds" % int(
			ceil(sound_remaining)
		)
	elif sound_cooldown > 0.0:
		sound_button.text = "RECARREGANDO... %ds" % int(
			ceil(sound_cooldown)
		)
	else:
		sound_button.text = "REPRODUZIR SOM"
