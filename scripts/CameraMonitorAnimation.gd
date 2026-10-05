extends Node
## Anima o painel existente. Não altera a IA nem a imagem das câmeras.

var panel: Control
var motion: Tween
var resting_position := Vector2.ZERO
var resting_scale := Vector2.ONE
var resting_rotation := 0.0
var resting_pivot := Vector2.ZERO
var moving := false
var closing := false
var open_duration := 0.25
var close_duration := 0.20


func configure(target: Control) -> void:
	panel = target
	remember_pose()


func remember_pose() -> void:
	resting_position = panel.position
	resting_scale = panel.scale
	resting_rotation = panel.rotation
	resting_pivot = panel.pivot_offset


func stop_motion() -> void:
	if motion != null and motion.is_valid():
		motion.kill()


func restore_pose() -> void:
	panel.position = resting_position
	panel.scale = resting_scale
	panel.rotation = resting_rotation
	panel.pivot_offset = resting_pivot


func open_monitor() -> void:
	if panel.visible and not closing:
		return
	stop_motion()
	if not moving:
		remember_pose()
	if not panel.visible:
		panel.pivot_offset = Vector2(panel.size.x * 0.5, panel.size.y)
		panel.position = resting_position + Vector2(0.0, panel.size.y)
		panel.scale = resting_scale * Vector2(0.96, 0.80)
		panel.rotation = resting_rotation + deg_to_rad(4.0)
	closing = false
	moving = true
	panel.show()
	motion = create_tween().set_parallel(true)
	motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(panel, "position", resting_position, open_duration)
	motion.tween_property(panel, "scale", resting_scale, open_duration)
	motion.tween_property(panel, "rotation", resting_rotation, open_duration)
	motion.chain().tween_callback(func() -> void:
		restore_pose()
		moving = false
	)


func close_monitor(immediate: bool = false) -> void:
	if immediate or not panel.visible:
		stop_motion()
		panel.hide()
		if moving:
			restore_pose()
		moving = false
		closing = false
		return
	if closing:
		return
	stop_motion()
	if not moving:
		remember_pose()
		panel.pivot_offset = Vector2(panel.size.x * 0.5, panel.size.y)
	moving = true
	closing = true
	motion = create_tween().set_parallel(true)
	motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.tween_property(panel, "position",
		resting_position + Vector2(0.0, panel.size.y), close_duration)
	motion.tween_property(panel, "scale",
		resting_scale * Vector2(0.96, 0.80), close_duration)
	motion.tween_property(panel, "rotation",
		resting_rotation + deg_to_rad(4.0), close_duration)
	motion.chain().tween_callback(func() -> void:
		panel.hide()
		restore_pose()
		moving = false
		closing = false
	)
