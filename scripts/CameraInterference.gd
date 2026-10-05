extends ColorRect
## Efeito visual independente: continua terminando mesmo se a IA for pausada.

var camera_system: Node
var camera_panel: Control
var last_state: Array = []
var remaining := 0.0
var duration := 0.40
var effect_material: ShaderMaterial


func configure(system: Node, background: TextureRect, panel: Control) -> void:
	camera_system = system
	camera_panel = panel
	name = "CameraInterference"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	use_parent_material = false
	z_index = 20
	background.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var effect_shader := Shader.new()
	effect_shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform float strength = 0.0;
uniform bool night_vision = false;

float random_value(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    float frame = floor(TIME * 30.0);
    vec2 pixel = floor(UV * vec2(640.0, 360.0));
    float grain = random_value(pixel + vec2(frame * 13.0, frame));
    float row = floor(UV.y * 85.0);
    float stripe = step(0.80, random_value(vec2(row, frame)));
    float rolling = 1.0 - smoothstep(0.0, 0.045,
        abs(UV.y - fract(TIME * 2.7)));
    float value = clamp(grain * 0.65 + stripe * 0.22 + rolling * 0.15, 0.0, 1.0);
    vec3 tint = night_vision ? vec3(0.22, 1.0, 0.32) : vec3(1.0);
    float opacity = clamp(strength * (0.65 + stripe * 0.25), 0.0, 0.95);
    COLOR = vec4(tint * value, opacity);
}
"""
	effect_material = ShaderMaterial.new()
	effect_material.shader = effect_shader
	material = effect_material
	last_state = read_state()
	hide()
	# Executa depois da atualização normal dos scripts do jogo.
	process_priority = 100


func read_state() -> Array:
	return [
		camera_system.get("antonio_camera"),
		camera_system.get("antonio_spot"),
		camera_system.get("patio_head_up"),
		camera_system.get("patio_standing"),
		camera_system.get("antonio_waiting_at_window"),
		camera_system.get("rear_antonio_present")
	]


func _process(delta: float) -> void:
	if not is_instance_valid(camera_system) or effect_material == null:
		return
	var state := read_state()
	var changed := state != last_state
	var selected := int(camera_system.get("current_camera"))
	var affected := selected == int(state[0]) or selected == int(last_state[0])
	if selected == 9:
		affected = state[4] != last_state[4] or state[5] != last_state[5]
	last_state = state
	if not camera_panel.is_visible_in_tree():
		remaining = 0.0
		hide()
		return
	if changed and affected:
		remaining = duration
	else:
		remaining = maxf(0.0, remaining - delta)
	visible = remaining > 0.0
	if not visible:
		return
	effect_material.set_shader_parameter("strength", remaining / duration)
	effect_material.set_shader_parameter(
		"night_vision", bool(camera_system.get("night_vision_on"))
	)
