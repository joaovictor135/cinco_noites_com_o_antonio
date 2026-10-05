extends Node

var active := false
var office
var elapsed := 0.0
var waiting_time := 0.0
var warning_time := 3.0
var layer: CanvasLayer
var shadow: TextureRect


func start(controller: Node) -> void:
	office = controller
	active = true
	elapsed = 0.0
	waiting_time = randf_range(6.0, 10.0)
	# O relógio pode registrar a vitória antes de processarmos o ataque.
	process_priority = 10
	layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var darkness := ColorRect.new()
	darkness.color = Color(0.0, 0.0, 0.0, 0.94)
	darkness.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(darkness)
	darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow = TextureRect.new()
	var body := AtlasTexture.new()
	body.atlas = preload("res://sprites/antonio/antonio.png")
	var size: Vector2 = body.atlas.get_size()
	body.region = Rect2(0.0, 0.0, size.x, size.y * 0.48)
	body.filter_clip = true
	shadow.texture = body
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkness.add_child(shadow)
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.anchor_left = 0.30
	shadow.anchor_top = 0.16
	shadow.anchor_right = 0.70
	shadow.anchor_bottom = 0.94
	shadow.hide()


func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(office) or office.game_over:
		cancel()
		return
	elapsed += delta
	if elapsed >= waiting_time:
		shadow.show()
		var reveal := clampf((elapsed - waiting_time) / 1.0, 0.0, 1.0)
		shadow.self_modulate = Color(0.24, 0.26, 0.30, reveal)
	if elapsed >= waiting_time + warning_time:
		active = false
		office.finish_game(false)


func cancel() -> void:
	active = false
	if is_instance_valid(layer):
		layer.hide()
		layer.queue_free()
	queue_free()
