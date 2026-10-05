extends CanvasLayer
## Pausa somente a partida; não assume a pausa da tela de entrada.

var office
var owns_pause := false
var resume_button: Button
var message: Label


func configure(controller: Node) -> void:
	office = controller
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 150
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.015, 0.025, 0.92)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	backdrop.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	var title := Label.new()
	title.text = "PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	column.add_child(title)
	resume_button = make_button(column, "CONTINUAR")
	resume_button.pressed.connect(resume_game)
	var menu_button := make_button(column, "VOLTAR AO MENU")
	menu_button.pressed.connect(return_to_menu)
	var note := Label.new()
	note.text = "Ao sair, a noite atual recomeça.\nAs noites desbloqueadas ficam salvas."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 16)
	note.modulate = Color(0.72, 0.75, 0.80)
	column.add_child(note)
	message = Label.new()
	message.custom_minimum_size.x = 340.0
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.modulate = Color(1.0, 0.4, 0.35)
	column.add_child(message)
	hide()


func make_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340.0, 56.0)
	button.add_theme_font_size_override("font_size", 22)
	parent.add_child(button)
	return button


func _input(event: InputEvent) -> void:
	if not is_instance_valid(office):
		return
	if not event is InputEventKey:
		return
	if event.keycode != KEY_ESCAPE or not event.pressed or event.echo:
		return
	if office.game_over:
		return
	# Não libera nem sobrepõe uma pausa criada por outro sistema.
	if get_tree().paused and not owns_pause:
		return
	get_viewport().set_input_as_handled()
	if owns_pause:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	if office.game_over or get_tree().paused:
		return
	message.text = ""
	owns_pause = true
	get_tree().paused = true
	show()
	resume_button.grab_focus()


func resume_game() -> void:
	if not owns_pause:
		return
	hide()
	resume_button.release_focus()
	owns_pause = false
	get_tree().paused = false


func return_to_menu() -> void:
	resume_game()
	var error := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if error != OK:
		pause_game()
		message.text = "Não foi possível abrir o menu: " + error_string(error)


func _exit_tree() -> void:
	if owns_pause:
		get_tree().paused = false
		owns_pause = false
