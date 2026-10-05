extends CanvasLayer
## Telas de entrada e de vitória, sem áudio.

var background: ColorRect
var held_pause := false
var previous_pause := false


func build_screen() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	background = ColorRect.new()
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func play_intro(night: int) -> void:
	build_screen()
	previous_pause = get_tree().paused
	held_pause = true
	get_tree().paused = true
	var center := CenterContainer.new()
	background.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var title := Label.new()
	title.text = "NOITE %d" % night
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	column.add_child(title)
	var clock := Label.new()
	clock.text = "00:00"
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.add_theme_font_size_override("font_size", 70)
	column.add_child(clock)
	var animation := create_tween()
	animation.tween_interval(2.0)
	animation.tween_property(background, "modulate:a", 0.0, 0.35)
	await animation.finished
	release_pause()
	hide()
	queue_free()


func play_victory() -> void:
	build_screen()
	var center := CenterContainer.new()
	background.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(360.0, 110.0)
	frame.clip_contents = true
	column.add_child(frame)
	var before := make_clock(frame, "05:59", 0.0)
	var after := make_clock(frame, "06:00", 110.0)
	var caption := Label.new()
	caption.text = "VOCÊ SOBREVIVEU"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 26)
	caption.modulate.a = 0.0
	column.add_child(caption)
	var animation := create_tween()
	animation.tween_interval(0.65)
	animation.tween_property(before, "position:y", -110.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	animation.parallel().tween_property(after, "position:y", 0.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	animation.tween_property(caption, "modulate:a", 1.0, 0.30)
	animation.tween_interval(1.3)
	# A tela de resultados é criada pelo OfficeController ao terminar.
	await animation.finished
	hide()
	queue_free()


func make_clock(parent: Control, text: String, y: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0.0, y)
	label.size = Vector2(360.0, 110.0)
	parent.add_child(label)
	return label


func release_pause() -> void:
	if held_pause:
		get_tree().paused = previous_pause
		held_pause = false


func _exit_tree() -> void:
	release_pause()
