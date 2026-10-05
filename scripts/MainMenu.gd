extends Control

const SAVE_PATH := "user://progress.cfg"
const OFFICE_SCENE := "res://scenes/office.tscn"
var saved_night := 1
var has_save := false
var completed := false
var save_read_error := false
var error_label: Label
var confirmation: ConfirmationDialog


func _ready() -> void:
	var config := ConfigFile.new()
	var result := config.load(SAVE_PATH)
	has_save = result == OK and config.has_section_key("progress", "unlocked_night")
	save_read_error = result != OK and result != ERR_FILE_NOT_FOUND
	if has_save:
		saved_night = clampi(int(config.get_value("progress", "unlocked_night", 1)), 1, 5)
		completed = bool(config.get_value("progress", "completed_game", false))
	var image := TextureRect.new()
	image.texture = preload("res://sprites/office/office_central.png")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.03, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var title := Label.new()
	title.text = "CINCO NOITES\nCOM O ANTÔNIO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	column.add_child(title)
	var status := Label.new()
	status.text = "★ Cinco noites concluídas" if completed else "Sobreviva até as 06:00"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.modulate = Color(0.75, 0.78, 0.82)
	column.add_child(status)
	var resume := make_button(column, "CONTINUAR — NOITE %d" % saved_night)
	resume.disabled = not has_save
	resume.pressed.connect(enter_office)
	var fresh := make_button(column, "NOVO JOGO")
	fresh.pressed.connect(request_new_game)
	var help_button := make_button(column, "COMO JOGAR")
	help_button.pressed.connect(show_instructions)
	var leave := make_button(column, "SAIR")
	leave.pressed.connect(func() -> void: get_tree().quit())
	error_label = Label.new()
	error_label.custom_minimum_size.x = 360.0
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.modulate = Color(1.0, 0.45, 0.40)
	column.add_child(error_label)
	if save_read_error:
		error_label.text = "Não foi possível ler o progresso salvo."
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Novo jogo"
	confirmation.dialog_text = "Começar pela noite 1 e substituir o progresso salvo?"
	confirmation.ok_button_text = "COMEÇAR"
	confirmation.cancel_button_text = "CANCELAR"
	confirmation.confirmed.connect(start_new_game)
	add_child(confirmation)
	if has_save:
		resume.grab_focus()
	else:
		fresh.grab_focus()


func make_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360.0, 54.0)
	button.add_theme_font_size_override("font_size", 21)
	parent.add_child(button)
	return button


func request_new_game() -> void:
	if has_save or save_read_error:
		confirmation.popup_centered()
	else:
		start_new_game()


func start_new_game() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("progress", "unlocked_night", 1)
	config.set_value("progress", "completed_game", false)
	var result := config.save(SAVE_PATH)
	if result != OK:
		error_label.text = "Não foi possível salvar: " + error_string(result)
		return
	enter_office()


func enter_office() -> void:
	var result := get_tree().change_scene_to_file(OFFICE_SCENE)
	if result != OK:
		error_label.text = "Não foi possível abrir o jogo: " + error_string(result)

func show_instructions() -> void:
	var instructions := AcceptDialog.new()
	instructions.title = "Como jogar"
	instructions.ok_button_text = "VOLTAR"

	instructions.dialog_text = """COMO JOGAR

• Sobreviva até as 06:00.

• Mova o mouse para os lados para olhar o escritório.

• Use as câmeras para encontrar Antônio.

• Feche a porta quando ele chegar à entrada.

• Abra a cortina para esfriar a sala.
  Não deixe a temperatura chegar a 40 °C.

• Economize energia: equipamentos e porta fechada
  gastam bateria. Cada noite fica mais difícil.

• O susto da janela não mata."""

	add_child(instructions)
	instructions.confirmed.connect(instructions.queue_free)
	instructions.canceled.connect(instructions.queue_free)
	instructions.popup_centered()
