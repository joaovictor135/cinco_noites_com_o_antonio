extends TextureRect
## Recorta a passagem do personagem pelas grades, usando o próprio cenário.
## Coordenadas ajustadas aos fundos mostrados nas capturas de 01/10/2026.

var background: TextureRect
var character: TextureRect
var active_when: Callable
var camera_view := false
var masked_material: ShaderMaterial
var original_material: ShaderMaterial

const MASK_CODE := """
float window_segment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    return length(p - (a + t * ab));
}

bool window_foreground(vec2 uv) {
    if (WINDOW_CAMERA) {
        vec2 p = uv * vec2(1672.0, 941.0);
        // Cortinas, laterais e parede abaixo do parapeito.
        float left = mix(355.0, 398.0, (p.y - 155.0) / 310.0);
        float bottom = 460.0 + (p.x - 444.0) * (-21.0 / 310.0);
        if (p.x < left || p.x > 755.0 || p.y < 156.0 || p.y > bottom) {
            return true;
        }
        return (
            window_segment(p, vec2(359, 148), vec2(763, 188)) < 6.0 ||
            window_segment(p, vec2(363, 184), vec2(761, 221)) < 4.5 ||
            window_segment(p, vec2(368, 220), vec2(759, 249)) < 4.5 ||
            window_segment(p, vec2(374, 257), vec2(758, 277)) < 4.5 ||
            window_segment(p, vec2(379, 294), vec2(758, 305)) < 4.5 ||
            window_segment(p, vec2(384, 332), vec2(757, 334)) < 4.0 ||
            window_segment(p, vec2(388, 363), vec2(756, 360)) < 4.0 ||
            window_segment(p, vec2(393, 397), vec2(755, 385)) < 4.0 ||
            window_segment(p, vec2(398, 431), vec2(754, 411)) < 4.0 ||
            window_segment(p, vec2(444, 460), vec2(754, 439)) < 5.0 ||
            window_segment(p, vec2(493, 163), vec2(516, 455)) < 5.0 ||
            window_segment(p, vec2(536, 168), vec2(557, 452)) < 4.5 ||
            window_segment(p, vec2(687, 184), vec2(698, 443)) < 4.0
        );
    }
    vec2 p = uv * vec2(1152.0, 648.0);
    float left = mix(31.0, 70.0, p.y / 353.0);
    float bottom = mix(353.0, 342.0, (p.x - 69.0) / 749.0);
    if (p.x < left || p.x > 820.0 || p.y > bottom) {
        return true;
    }
    return (
        window_segment(p, vec2(32, 19), vec2(822, 31)) < 6.0 ||
        window_segment(p, vec2(48, 105), vec2(822, 110)) < 5.5 ||
        window_segment(p, vec2(52, 128), vec2(822, 123)) < 5.5 ||
        window_segment(p, vec2(56, 185), vec2(821, 184)) < 6.0 ||
        window_segment(p, vec2(63, 271), vec2(820, 259)) < 6.0 ||
        window_segment(p, vec2(69, 353), vec2(818, 342)) < 6.0 ||
        window_segment(p, vec2(213, 0), vec2(225, 348)) < 6.5 ||
        window_segment(p, vec2(310, 0), vec2(323, 347)) < 6.5 ||
        window_segment(p, vec2(729, 0), vec2(726, 342)) < 6.0
    );
}
"""


func configure(source: TextureRect, actor: TextureRect,
		is_camera: bool, condition: Callable = Callable()) -> void:
	background = source
	character = actor
	camera_view = is_camera
	active_when = condition
	name = "WindowOccluder"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	use_parent_material = false
	source.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = actor.z_index + 1

	original_material = source.material as ShaderMaterial
	var code := "shader_type canvas_item;\nvoid fragment() { COLOR = texture(TEXTURE, UV); }"
	if original_material != null:
		code = original_material.shader.code
	var camera_constant := "const bool WINDOW_CAMERA = %s;\n" % (
		"true" if camera_view else "false"
	)
	code = code.replace("void fragment() {", camera_constant + MASK_CODE
		+ "\nvoid fragment() {\nif (!window_foreground(UV)) { discard; }\n")
	var mask_shader := Shader.new()
	mask_shader.code = code
	masked_material = ShaderMaterial.new()
	masked_material.shader = mask_shader
	material = masked_material
	_process(0.0)


func _process(_delta: float) -> void:
	if not is_instance_valid(background) or not is_instance_valid(character):
		hide()
		return
	visible = character.visible
	if active_when.is_valid():
		visible = visible and bool(active_when.call())
	if not visible:
		return
	texture = background.texture
	stretch_mode = background.stretch_mode
	texture_filter = background.texture_filter
	self_modulate = background.self_modulate
	if original_material != null:
		var parameters := ["enabled", "brightness", "camera_darkness"] if camera_view else [
			"enabled", "beam_center", "beam_radius"
		]
		for parameter in parameters:
			masked_material.set_shader_parameter(
				parameter, original_material.get_shader_parameter(parameter)
			)
