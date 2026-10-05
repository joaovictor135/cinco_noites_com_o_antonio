extends Node

signal power_changed(new_power: float)
signal power_out()

var power: float = 100.0
var is_power_out: bool = false

var base_drain: float = 0.04
var door_drain: float = 0.18
var light_drain: float = 0.25
var camera_drain: float = 0.40
var night_multiplier: float = 1.0

var left_door_closed: bool = false
var right_door_closed: bool = false
var left_light_on: bool = false
var right_light_on: bool = false
var is_on_cameras: bool = false
var night_vision_on: bool = false
var night_vision_drain: float = 0.30

func _process(delta: float) -> void:
	if is_power_out:
		return

	power = clampf(
		power - get_current_drain() * delta,
		0.0,
		100.0
	)

	power_changed.emit(power)

	if power <= 0.0:
		is_power_out = true
		power_out.emit()

func set_left_door(closed: bool) -> void:
	left_door_closed = closed

func set_right_door(closed: bool) -> void:
	right_door_closed = closed

func set_left_light(on: bool) -> void:
	left_light_on = on

func set_right_light(on: bool) -> void:
	right_light_on = on

func set_cameras(active: bool) -> void:
	is_on_cameras = active
	
func set_night_vision(active: bool) -> void:
	night_vision_on = active and not is_power_out
	
func _ready() -> void:
	var usage = preload("res://scripts/PowerUsageIndicator.gd").new()
	usage.configure(self, $"../../UI")


func get_current_drain() -> float:
	if is_power_out:
		return 0.0

	var drain: float = base_drain

	if left_door_closed:
		drain += door_drain
	if right_door_closed:
		drain += door_drain

	if left_light_on:
		drain += light_drain
	if right_light_on:
		drain += light_drain

	if is_on_cameras:
		drain += camera_drain
		if night_vision_on:
			drain += night_vision_drain

	return maxf(0.0, drain * night_multiplier)
