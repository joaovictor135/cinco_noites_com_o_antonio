extends Node

enum OfficeView { CENTER, LEFT, RIGHT }

@onready var power_system = $"../PowerSystem"
@onready var camera_system = $"../CameraSystem"

@onready var office_image = $"../../UI/OfficeImage"
@onready var camera_panel = $"../../UI/CameraPanel"
@onready var power_label = $"../../UI/PowerLabel"
@onready var night_label = $"../../UI/NightLabel"

@onready var btn_door_left = $"../../UI/DoorLeftButton"
@onready var btn_door_right = $"../../UI/DoorRightButton"
@onready var btn_light_left = $"../../UI/LightLeftButton"
@onready var btn_light_right = $"../../UI/LightRightButton"
@onready var btn_camera = $"../../UI/CameraButton"

var office_textures: Array[Texture2D] = [
	preload("res://sprites/office/office_central.png"),
	preload("res://sprites/office/office_left_fechado.png"),
	preload("res://sprites/office/office_door_fechada.png")
]

# Os nomes dos nós antigos continuam iguais para não quebrar a cena.
var curtain_open: bool = false
var curtain_button: Button
var curtain_open_texture: Texture2D = preload(
	"res://sprites/office/office_left_aberta.png"
)

var current_view: int = OfficeView.CENTER
var door_closed: bool = false
var flashlight_on: bool = false
var flashlight_material: ShaderMaterial
var door_open_texture: Texture2D = preload(
	"res://sprites/office/office_door_aberta.png"
)
var antonio_door_image: TextureRect
var door_open_elapsed: float = 0.0
var door_closed_elapsed: float = 0.0

var attack_delay: float = 5.0
var retreat_delay: float = 3.0

var game_over: bool = false

# Regras de temperatura do jogo, ajustáveis no Inspetor.
@export var heat_gain_per_second: float = 0.25
@export var faint_temperature: float = 40.0
const CONTROLLED_TEMPERATURE: float = 15.0
var room_temperature: float = CONTROLLED_TEMPERATURE
var temperature_label: Label
var heat_blink_elapsed: float = 0.0

var door_uses: int = 0
var door_max_uses: int = 3
var door_lock_remaining: float = 0.0
var door_lock_duration: float = 10.0

var ambush_image: TextureRect
var ambush_active: bool = false
var ambush_elapsed: float = 0.0
var ambush_seen_elapsed: float = 0.0

# Ative para testar só a emboscada.
var force_right_ambush: bool = false

@export var rear_attack_delay: float = 6.0
var window_scare_image: TextureRect
var window_scare_audio: AudioStreamPlayer
var window_scare_active: bool = false
var window_scare_elapsed: float = 0.0
var window_scare_wait: float = 0.0
var window_scare_tween: Tween
var blackout_active: bool = false
var blackout_sequence
var extra_characters

func _ready() -> void:
	create_flashlight()
	setup_office_controls()

	office_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	office_image.stretch_mode = TextureRect.STRETCH_SCALE
	office_image.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	office_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# A mesa já faz parte das novas imagens.
	# Esconde os elementos antigos sem precisar apagá-los.
	for node_name in [
		"Background", "Desk",
		"DoorLeft", "DoorRight",
		"LightLeft", "LightRight"
	]:
		var old_node = get_node_or_null("../../" + node_name)
		if old_node is CanvasItem:
			old_node.hide()

	btn_door_right.hide()
	btn_light_right.hide()

	btn_door_left.pressed.connect(_on_door_left_pressed)
	btn_light_left.pressed.connect(_on_light_left_pressed)
	btn_camera.pressed.connect(_on_camera_pressed)

	power_system.power_changed.connect(_on_power_changed)
	power_system.power_out.connect(_on_power_out)
	camera_panel.visibility_changed.connect(_update_controls)

	# Desativa o consumo dos controles antigos.
	power_system.set_right_door(false)
	power_system.set_right_light(false)
	power_system.set_left_door(false)
	power_system.set_left_light(false)

	power_label.text = "Energia: %d%%" % int(power_system.power)

	_set_view(OfficeView.CENTER)

	create_antonio_at_door()
	create_right_ambush()
	create_window_scare()
	create_temperature_display()
	# Aguarda os dois nós terminarem a inicialização.
	call_deferred("sync_rear_camera")

	if power_system.is_power_out:
		_on_power_out()
		
	var pause_menu = preload("res://scripts/PauseMenu.gd").new()
	add_child(pause_menu)
	pause_menu.configure(self)
	
	extra_characters = preload("res://scripts/ExtraCharacters.gd").new()
	add_child(extra_characters)
	extra_characters.configure.call_deferred(self)


func _input(event: InputEvent) -> void:
	if game_over or blackout_active or window_scare_active:
		return

	if not event is InputEventMouseMotion:
		return

	# Não muda o escritório enquanto olha as câmeras.
	if camera_panel.visible:
		return

	var viewport_rect = get_viewport().get_visible_rect()
	var mouse_position = get_viewport().get_mouse_position()

	if not viewport_rect.has_point(mouse_position):
		return

	# Mantém a visão enquanto o mouse usa os botões.
	for button in [
		btn_door_left, btn_light_left, btn_camera, curtain_button
	]:
		if button.is_visible_in_tree():
			if button.get_global_rect().has_point(mouse_position):
				return

	var relative_x: float = (
		(mouse_position.x - viewport_rect.position.x)
		/ viewport_rect.size.x
	)

	# Cantos: vistas laterais.
	# Meio: vista central.
	# Pequenas faixas entre eles evitam ficar piscando.
	if relative_x <= 0.20:
		_set_view(OfficeView.LEFT)
	elif relative_x >= 0.80:
		_set_view(OfficeView.RIGHT)
	elif relative_x >= 0.35 and relative_x <= 0.65:
		_set_view(OfficeView.CENTER)


func _set_view(view: int) -> void:
	current_view = view
	if current_view != OfficeView.LEFT:
		stop_window_scare()

	if current_view != OfficeView.RIGHT:
		set_flashlight(false)

	update_office_image()
	_update_controls()

func _update_controls() -> void:
	var blocked: bool = game_over or ambush_active or blackout_active
	var office_visible: bool = not camera_panel.visible and not blocked
	var looking_right: bool = office_visible and current_view == OfficeView.RIGHT
	btn_door_left.visible = looking_right
	btn_light_left.visible = looking_right
	btn_camera.visible = not camera_panel.visible and not game_over and current_view == OfficeView.CENTER
	btn_door_right.hide()
	btn_light_right.hide()
	btn_door_left.disabled = blocked or power_system.is_power_out or door_lock_remaining > 0.0
	btn_light_left.disabled = blocked or power_system.is_power_out
	btn_camera.disabled = game_over or power_system.is_power_out or window_scare_active
	btn_door_left.text = "PORTA"
	btn_light_left.text = "LUZ"
	if is_instance_valid(curtain_button):
		curtain_button.visible = office_visible and current_view == OfficeView.LEFT
		curtain_button.disabled = blocked
		curtain_button.text = "FECHAR CORTINA" if curtain_open else "ABRIR CORTINA"

func _on_door_left_pressed() -> void:
	if game_over or ambush_active or power_system.is_power_out:
		return

	if camera_panel.visible or current_view != OfficeView.RIGHT:
		return

	if door_lock_remaining > 0.0:
		return

	if door_closed:
		door_closed = false

		# O terceiro fechamento funciona normalmente.
		# Ao reabrir, começa o bloqueio.
		if door_uses >= door_max_uses:
			door_lock_remaining = door_lock_duration
	else:
		door_closed = true
		door_uses += 1

	power_system.set_left_door(door_closed)
	update_office_image()
	_update_controls()


func _on_light_left_pressed() -> void:
	set_flashlight(not flashlight_on)


func _on_camera_pressed() -> void:
	if game_over or power_system.is_power_out or window_scare_active:
		return

	stop_window_scare()
	set_flashlight(false)
	camera_system.open_cameras()


func _on_power_changed(new_power: float) -> void:
	power_label.text = "Energia: %d%%" % int(new_power)


func _on_power_out() -> void:
	if game_over or blackout_active:
		return
	blackout_active = true
	ambush_active = false
	window_scare_active = false
	stop_window_scare()
	set_flashlight(false)
	door_closed = false
	flashlight_on = false
	power_label.text = "Energia: 0%"
	power_label.modulate = Color.RED
	power_system.set_left_door(false)
	power_system.set_right_door(false)
	power_system.set_left_light(false)
	power_system.set_right_light(false)
	camera_system.close_cameras(true)
	camera_system.set_process(false)
	antonio_door_image.hide()
	ambush_image.hide()
	sync_rear_camera()
	_update_controls()
	update_office_image()
	blackout_sequence = preload("res://scripts/BlackoutSequence.gd").new()
	add_child(blackout_sequence)
	blackout_sequence.start(self)

func create_flashlight() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform bool enabled = false;

// Porta ao fundo da passagem na vista DIREITA.
uniform vec2 beam_center = vec2(0.475, 0.38);

// Largura e altura do foco.
uniform vec2 beam_radius = vec2(0.105, 0.32);

void fragment() {
	vec4 original = COLOR;

	if (enabled) {
		vec2 distance_from_center = (
			(UV - beam_center) / beam_radius
		);

		float distance_value = length(distance_from_center);
		float beam = 1.0 - smoothstep(
			0.30, 1.0, distance_value
		);

		// Clareia os detalhes existentes na imagem.
		vec3 illuminated = pow(
			max(original.rgb, vec3(0.0)),
			vec3(0.48)
		) * 1.35;

		illuminated = clamp(
			illuminated, vec3(0.0), vec3(1.0)
		);

		COLOR = vec4(
			mix(original.rgb, illuminated, beam),
			original.a
		);
	} else {
		COLOR = original;
	}
}
"""

	flashlight_material = ShaderMaterial.new()
	flashlight_material.shader = shader
	office_image.use_parent_material = false
	office_image.material = flashlight_material


func set_flashlight(active: bool) -> void:
	flashlight_on = (
		active
		and not game_over
		and not ambush_active
		and current_view == OfficeView.RIGHT
		and not camera_panel.visible
		and not power_system.is_power_out
	)

	flashlight_material.set_shader_parameter(
		"enabled", flashlight_on
	)
	power_system.set_right_light(flashlight_on)
	_update_controls()

func update_office_image() -> void:
	if current_view == OfficeView.RIGHT and not door_closed:
		office_image.texture = door_open_texture
	elif current_view == OfficeView.LEFT and curtain_open:
		office_image.texture = curtain_open_texture
	else:
		office_image.texture = office_textures[current_view]

func create_antonio_at_door() -> void:
	antonio_door_image = TextureRect.new()
	antonio_door_image.name = "AntonioAtDoor"

	antonio_door_image.texture = preload(
		"res://sprites/antonio/antonio.png"
	)

	antonio_door_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	antonio_door_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	antonio_door_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Não herda o shader: o foco dele usa as coordenadas do cenário.
	antonio_door_image.use_parent_material = false
	antonio_door_image.self_modulate = Color(0.65, 0.65, 0.65, 1.0)

	office_image.add_child(antonio_door_image)

	# Área dentro da abertura da porta.
	# Valores proporcionais ao tamanho da imagem.
		# Posição e tamanho dentro da abertura da porta.
	antonio_door_image.anchor_left = 0.425
	antonio_door_image.anchor_top = 0.25
	antonio_door_image.anchor_right = 0.555
	antonio_door_image.anchor_bottom = 0.62

	antonio_door_image.offset_left = 0.0
	antonio_door_image.offset_top = 0.0
	antonio_door_image.offset_right = 0.0
	antonio_door_image.offset_bottom = 0.0

	antonio_door_image.hide()


func _process(delta: float) -> void:
	if game_over:
		return

	update_room_temperature(delta)
	if game_over:
		return

	if blackout_active:
		return

	if ambush_active:
		update_right_ambush(delta)
		return

	update_window_scare(delta)

	# Atualiza o bloqueio mesmo quando Antonio não está na porta.
	if door_lock_remaining > 0.0:
		door_lock_remaining = maxf(
			door_lock_remaining - delta, 0.0
		)

		if door_lock_remaining <= 0.0:
			door_uses = 0

		_update_controls()

	if not is_instance_valid(antonio_door_image):
		return

	# Aparência do Antonio na entrada.
	antonio_door_image.visible = (
		camera_system.antonio_at_door
		and current_view == OfficeView.RIGHT
		and not camera_panel.visible
		and not door_closed
	)

	if flashlight_on and not power_system.is_power_out:
		antonio_door_image.self_modulate = Color(
			0.65, 0.65, 0.65, 1.0
		)
	else:
		antonio_door_image.self_modulate = Color(
			0.10, 0.10, 0.10, 1.0
		)

	# Ataque e recuo só contam enquanto ele está na entrada.
	if not camera_system.antonio_at_door:
		door_open_elapsed = 0.0
		door_closed_elapsed = 0.0
		return

	if door_closed:
		door_open_elapsed = 0.0
		door_closed_elapsed += delta

		if door_closed_elapsed >= retreat_delay:
			door_closed_elapsed = 0.0
			camera_system.reset_antonio_to_patio()
			antonio_door_image.hide()

			print("Antonio recuou para o pátio.")
	else:
		door_closed_elapsed = 0.0
		door_open_elapsed += delta

		if door_open_elapsed >= attack_delay:
			trigger_antonio_attack()


func finish_game(won: bool = false, cause: String = "antonio") -> void:
	if game_over:
		return

	game_over = true
	if is_instance_valid(extra_characters):
		extra_characters.stop()
	if is_instance_valid(blackout_sequence):
		blackout_sequence.cancel()
	stop_window_scare()
	ambush_active = false
	sync_rear_camera()

	if is_instance_valid(ambush_image):
		ambush_image.hide()
	$"../GameManager".stop_clock()
	if won:
		$"../GameManager".register_victory()

	set_flashlight(false)
	camera_system.close_cameras(true)
	antonio_door_image.hide()

	# Interrompe movimentação e consumo após a derrota.
	camera_system.set_process(false)
	power_system.set_process(false)
	set_process_input(false)

	btn_door_left.disabled = true
	btn_light_left.disabled = true
	btn_camera.disabled = true

	if won:
		var transition = preload("res://scripts/NightTransition.gd").new()
		add_child(transition)
		await transition.play_victory()
	elif cause in ["lindenberg", "negrelo"]:
		await extra_characters.play_jumpscare(cause)
	elif cause == "heat":
		await play_heat_faint()
	else:
		await play_front_jumpscare()

	# Tela acima de toda a interface.
	var end_layer := CanvasLayer.new()
	end_layer.layer = 100
	add_child(end_layer)

	var background := ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.95)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	end_layer.add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var center := CenterContainer.new()
	background.add_child(center)
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	center.add_child(content)

	var title := Label.new()
	title.text = "06:00 — VOCÊ VENCEU!" if won else "FIM DE JOGO"
	if not won and cause == "heat":
		title.text = "VOCÊ DESMAIOU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	content.add_child(title)

	var message := Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if won:
		if $"../GameManager".current_night >= 5:
			message.text = "Você sobreviveu às cinco noites!"
		else:
			message.text = "Noite concluída! A próxima foi liberada."
	elif cause == "heat":
		message.text = "A sala chegou a %.0f °C. Abra a cortina para manter 15 °C." % faint_temperature
	elif cause == "lindenberg":
				message.text = "Lindenberg escapou da jaula. Rebobine a trava na CAM 03."
	elif cause == "negrelo":
		message.text = "Negrelo entrou. Feche a porta direita até ele recuar."
	else:
		message.text = "Antonio entrou na sala."
	content.add_child(message)

	var restart_button := Button.new()

	if won:
		if $"../GameManager".current_night >= 5:
			restart_button.text = "REINICIAR JOGO"
		else:
			restart_button.text = "PRÓXIMA NOITE"
	else:
		restart_button.text = "TENTAR NOVAMENTE"

	restart_button.custom_minimum_size = Vector2(280, 55)
	content.add_child(restart_button)
	if won and $"../GameManager".current_night >= 5:
		restart_button.pressed.connect(
			$"../GameManager".restart_from_first_night
		)
	else:
		restart_button.pressed.connect(restart_game)
		restart_button.grab_focus()
		
	var menu_button := Button.new()
	menu_button.text = "MENU PRINCIPAL"
	menu_button.custom_minimum_size = Vector2(280, 55)
	content.add_child(menu_button)
	menu_button.pressed.connect(return_to_main_menu)

func restart_game() -> void:
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		push_error("Não foi possível reiniciar: " + error_string(error))

func play_front_jumpscare() -> void:
	var scare_layer := CanvasLayer.new()
	scare_layer.layer = 110
	add_child(scare_layer)

	# Cobre a interface e bloqueia os cliques.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.015, 0.02, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	scare_layer.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var face := TextureRect.new()
	face.texture = preload(
		"res://sprites/antonio/antonio.png"
	)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(face)

	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var texture_size: Vector2 = face.texture.get_size()

	# Amplia sem deformar a proporção da imagem.
	var image_height: float = screen_size.y * 2.5
	face.size = Vector2(
		image_height * texture_size.x / texture_size.y,
		image_height
	)

	# Ponto aproximado do rosto na imagem de corpo inteiro.
	var face_point := Vector2(
		face.size.x * 0.5,
		face.size.y * 0.15
	)

	face.pivot_offset = face_point
	face.position = Vector2(
		screen_size.x * 0.5,
		screen_size.y * 0.38
	) - face_point

	var initial_position: Vector2 = face.position
	face.scale = Vector2(0.75, 0.75)

	# Avanço rápido na direção do jogador.
	var approach := create_tween()
	approach.tween_property(
		face,
		"scale",
		Vector2(1.35, 1.35),
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await approach.finished

	# Pequenos deslocamentos, sem flashes.
	var shake := create_tween()

	for _i in range(10):
		var offset := Vector2(
			randf_range(-9.0, 9.0),
			randf_range(-6.0, 6.0)
		)

		shake.tween_property(
			face,
			"position",
			initial_position + offset,
			0.055
		)

	shake.tween_property(
		face,
		"position",
		initial_position,
		0.05
	)
	shake.tween_interval(0.20)

	await shake.finished

	scare_layer.hide()
	scare_layer.queue_free()

func create_right_ambush() -> void:
	var original: Texture2D = preload(
		"res://sprites/antonio/antonio.png"
	)

	# Recorta a região da cabeça sem modificar o PNG.
	var head_texture := AtlasTexture.new()
	head_texture.atlas = original

	var original_size: Vector2 = original.get_size()

	# Recorte inicial aproximado: ajuste se necessário.
	head_texture.region = Rect2(
		original_size.x * 0.25,
		original_size.y * 0.02,
		original_size.x * 0.50,
		original_size.y * 0.20
	)
	head_texture.filter_clip = true

	ambush_image = TextureRect.new()
	ambush_image.name = "AntonioRightAmbush"
	ambush_image.texture = head_texture

	ambush_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ambush_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ambush_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ambush_image.use_parent_material = false
	ambush_image.self_modulate = Color(0.10, 0.10, 0.10, 1.0)

	office_image.add_child(ambush_image)

	# Cabeça grande no lado direito da tela.
	ambush_image.anchor_left = 0.55
	ambush_image.anchor_top = 0.32
	ambush_image.anchor_right = 0.98
	ambush_image.anchor_bottom = 1.07

	ambush_image.offset_left = 0.0
	ambush_image.offset_top = 0.0
	ambush_image.offset_right = 0.0
	ambush_image.offset_bottom = 0.0

	ambush_image.hide()


func trigger_antonio_attack() -> void:
	if game_over or ambush_active:
		return
	# Toda entrada passa pela presença visível na câmera 10.
	start_right_ambush()


func start_right_ambush() -> void:
	if game_over or ambush_active:
		return
	stop_window_scare()
	ambush_active = true
	ambush_elapsed = 0.0
	ambush_seen_elapsed = 0.0
	sync_rear_camera()
	camera_system.set_process(false)
	set_flashlight(false)
	antonio_door_image.hide()
	# A cabeça lateral antiga não é mais usada como susto.
	ambush_image.hide()
	# Não fecha o monitor nem muda a câmera selecionada.
	_update_controls()


func update_right_ambush(delta: float) -> void:
	ambush_elapsed += delta

	var looking_at_antonio: bool = (
		current_view == OfficeView.RIGHT
		and not camera_panel.visible
	)

	ambush_image.visible = looking_at_antonio

	if looking_at_antonio:
		ambush_seen_elapsed += delta
	else:
		ambush_seen_elapsed = 0.0

	if ambush_seen_elapsed >= 0.5 or ambush_elapsed >= rear_attack_delay:
		finish_game()


func setup_office_controls() -> void:
	place_office_button(btn_door_left, Vector2(1.0, 1.0), Rect2(-304, -76, 136, 52))
	place_office_button(btn_light_left, Vector2(1.0, 1.0), Rect2(-160, -76, 136, 52))
	place_office_button(btn_camera, Vector2(0.5, 1.0), Rect2(-90, -76, 180, 52))
	curtain_button = Button.new()
	curtain_button.name = "CurtainButton"
	office_image.get_parent().add_child(curtain_button)
	place_office_button(curtain_button, Vector2(0.0, 1.0), Rect2(24, -76, 200, 52))
	curtain_button.pressed.connect(_on_curtain_pressed)


func place_office_button(button: Button, anchor: Vector2, rect: Rect2) -> void:
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	button.anchor_left = anchor.x
	button.anchor_right = anchor.x
	button.anchor_top = anchor.y
	button.anchor_bottom = anchor.y
	button.offset_left = rect.position.x
	button.offset_top = rect.position.y
	button.offset_right = rect.end.x
	button.offset_bottom = rect.end.y
	button.focus_mode = Control.FOCUS_NONE


func _on_curtain_pressed() -> void:
	if (
		game_over
		or blackout_active
		or ambush_active
		or window_scare_active
		or camera_panel.visible
		or current_view != OfficeView.LEFT
	):
		return
	curtain_open = not curtain_open
	if not curtain_open:
		stop_window_scare()
	if curtain_open:
		room_temperature = CONTROLLED_TEMPERATURE
	update_temperature_display()
	sync_rear_camera()
	update_office_image()
	_update_controls()


func sync_rear_camera() -> void:
	var antonio_visible: bool = (
		ambush_active
		or (window_scare_active and curtain_open)
	)

	camera_system.set_rear_view_state(
		curtain_open,
		antonio_visible and not game_over
	)

func create_temperature_display() -> void:
	temperature_label = Label.new()
	temperature_label.name = "TemperatureLabel"
	temperature_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	temperature_label.z_index = 50
	temperature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	temperature_label.add_theme_font_size_override("font_size", 20)
	temperature_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	temperature_label.add_theme_constant_override("shadow_offset_x", 2)
	temperature_label.add_theme_constant_override("shadow_offset_y", 2)
	office_image.get_parent().add_child(temperature_label)
	temperature_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	temperature_label.offset_left = -330.0
	temperature_label.offset_top = 52.0
	temperature_label.offset_right = -20.0
	temperature_label.offset_bottom = 84.0
	update_temperature_display()


func update_room_temperature(delta: float) -> void:
	if curtain_open:
		room_temperature = CONTROLLED_TEMPERATURE
	else:
		room_temperature = minf(
			room_temperature + maxf(heat_gain_per_second, 0.0) * delta,
			faint_temperature
		)
	if not curtain_open and room_temperature >= faint_temperature - 4.0:
		heat_blink_elapsed = fmod(heat_blink_elapsed + delta, 0.8)
	else:
		heat_blink_elapsed = 0.0
	update_temperature_display()
	if not curtain_open and room_temperature >= faint_temperature:
		finish_game(false, "heat")


func update_temperature_display() -> void:
	if not is_instance_valid(temperature_label):
		return
	# Apenas o valor em graus, sem mensagens adicionais.
	temperature_label.text = ("%.1f °C" % room_temperature).replace(".", ",")
	if not curtain_open and room_temperature >= faint_temperature - 4.0:
		# Pisca em vermelho a partir de 36 °C com o limite padrão de 40 °C.
		var blink_alpha: float = 1.0 if heat_blink_elapsed < 0.4 else 0.25
		temperature_label.modulate = Color(1.0, 0.15, 0.10, blink_alpha)
	else:
		temperature_label.modulate = Color.WHITE


func play_heat_faint() -> void:
	# Apagão gradual sem o jumpscare do Antônio.
	var faint_layer := CanvasLayer.new()
	faint_layer.layer = 90
	add_child(faint_layer)
	var fade := ColorRect.new()
	fade.color = Color(0.0, 0.0, 0.0, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	faint_layer.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_property(fade, "color", Color.BLACK, 1.2)
	await tween.finished
	# A tela final (camada 100) aparece acima deste fundo preto.
func create_window_scare() -> void:
	var source: Texture2D = preload("res://sprites/antonio/antonio.png")
	var upper_body := AtlasTexture.new()
	upper_body.atlas = source
	var original_size: Vector2 = source.get_size()
	upper_body.region = Rect2(0.0, 0.0, original_size.x, original_size.y * 0.48)
	upper_body.filter_clip = true
	window_scare_image = TextureRect.new()
	window_scare_image.name = "AntonioWindowScare"
	window_scare_image.texture = upper_body
	window_scare_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	window_scare_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	window_scare_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_scare_image.use_parent_material = false
	window_scare_image.self_modulate = Color(0.40, 0.43, 0.47, 1.0)
	office_image.add_child(window_scare_image)
	window_scare_image.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	window_scare_image.anchor_left = 0.24
	window_scare_image.anchor_top = 0.045
	window_scare_image.anchor_right = 0.58
	window_scare_image.anchor_bottom = 0.495
	window_scare_image.hide()
	window_scare_audio = AudioStreamPlayer.new()
	window_scare_audio.stream = preload("res://sounds/susto_janela.wav")
	window_scare_audio.volume_db = -10.0
	add_child(window_scare_audio)
	window_scare_wait = randf_range(25.0, 45.0)
	var window_mask = preload("res://scripts/WindowOccluder.gd").new()
	window_mask.configure(office_image, window_scare_image, false)


func update_window_scare(delta: float) -> void:
	if not window_scare_active:
		return

	var looking_at_window: bool = (
		curtain_open
		and current_view == OfficeView.LEFT
		and not camera_panel.visible
		and not game_over
		and not ambush_active
	)

	if not looking_at_window:
		stop_window_scare()
		window_scare_elapsed = 0.0
		return

	if not window_scare_image.visible:
		window_scare_image.scale = Vector2.ONE
		window_scare_image.show()
		window_scare_audio.play()

	window_scare_elapsed += delta

	# Só sai após ser visto diretamente por 1,1 segundo.
	if window_scare_elapsed >= 1.1:
		finish_window_visit()

func start_window_scare() -> void:
	if game_over or blackout_active or ambush_active or window_scare_active:
		return

	window_scare_active = true
	window_scare_elapsed = 0.0

	# Fecha o monitor imediatamente.
	camera_system.close_cameras(true)
	set_flashlight(false)

	# Abre a cortina e normaliza a temperatura.
	curtain_open = true
	room_temperature = CONTROLLED_TEMPERATURE
	heat_blink_elapsed = 0.0
	update_temperature_display()

	# Vira para a janela e mostra Antônio.
	_set_view(OfficeView.LEFT)
	sync_rear_camera()
	update_window_scare(0.0)
	_update_controls()
	
func stop_window_scare() -> void:
	# Esconde a imagem ao mudar de vista ou fechar a cortina.
	# Antônio continua esperando do lado de fora.
	if is_instance_valid(window_scare_tween):
		window_scare_tween.kill()

	if is_instance_valid(window_scare_image):
		window_scare_image.hide()
		window_scare_image.scale = Vector2.ONE

	if is_instance_valid(window_scare_audio):
		window_scare_audio.stop()
		
func finish_window_visit() -> void:
	stop_window_scare()
	window_scare_active = false
	window_scare_elapsed = 0.0
	sync_rear_camera()

	# Retoma o percurso na câmera seguinte ao pátio.
	camera_system.antonio_waiting_at_window = false
	camera_system.patio_head_up = false
	camera_system.patio_standing = false
	camera_system.movement_elapsed = 0.0
		# Susto iniciado no corredor: volta para a mesma câmera.
	if (
		camera_system.antonio_camera == 7
		and camera_system.corridor_window_scare_used
	):
		camera_system.return_to_random_camera()
		sync_rear_camera()
		_update_controls()
		return
	camera_system.route_step += 1
	camera_system.antonio_camera = camera_system.antonio_route[
		camera_system.route_step
	]
	camera_system.choose_antonio_spot()
	camera_system.update_antonio()
	_update_controls()
	
func return_to_main_menu() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if error != OK:
		push_error("Erro ao abrir o menu: " + error_string(error))
