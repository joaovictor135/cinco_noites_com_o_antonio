extends HBoxContainer
## Mostra o consumo total real, incluindo o multiplicador da noite.

var power_system
var bars: Array[ColorRect] = []


func configure(system: Node, hud: Node) -> void:
	power_system = system
	name = "PowerUsageIndicator"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	add_theme_constant_override("separation", 5)
	hud.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(24.0, 52.0)
	var title := Label.new()
	title.text = "USO  "
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	for i in range(5):
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(13.0, 18.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		bars.append(bar)
	_process(0.0)


func _process(_delta: float) -> void:
	if not is_instance_valid(power_system):
		return
	var rate: float = power_system.get_current_drain()
	var level := 0
	if rate > 0.0:
		level = 1
		for threshold in [0.10, 0.30, 0.55, 0.80]:
			if rate > threshold:
				level += 1
	var active_color := Color(0.25, 0.90, 0.40)
	if level >= 4:
		active_color = Color(1.0, 0.25, 0.18)
	elif level == 3:
		active_color = Color(1.0, 0.78, 0.18)
	for i in range(bars.size()):
		bars[i].color = active_color if i < level else Color(0.16, 0.18, 0.20)
