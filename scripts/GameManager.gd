extends Node

const SAVE_PATH: String = "user://progress.cfg"
const MAX_NIGHTS: int = 5

@onready var night_label = $"../../UI/NightLabel"
@onready var office_controller = $"../OfficeController"
@onready var camera_system = $"../CameraSystem"

var current_night: int = 1
var unlocked_night: int = 1
var completed_game: bool = false

var current_hour: int = 0
var seconds_per_hour: float = 60.0
var elapsed_time: float = 0.0
var night_finished: bool = false

var movement_times: Array[float] = [
	8.0, 7.0, 6.0, 5.0, 4.0
]

var attack_times: Array[float] = [
	5.0, 4.5, 4.0, 3.5, 3.0
]


func _ready() -> void:
	load_progress()
	current_night = unlocked_night
	update_clock()
	apply_difficulty.call_deferred()

	var transition = preload("res://scripts/NightTransition.gd").new()
	add_child(transition)
	await transition.play_intro(current_night)

	print("Noite ", current_night, " iniciada")


func apply_difficulty() -> void:
	var index: int = current_night - 1
	var start_hours: Array[int] = [3, 1, 1, 0, 0]
	camera_system.antonio_start_hour = start_hours[index]
	$"../PowerSystem".night_multiplier = 1.0 + float(index) * 0.10

	camera_system.movement_interval = movement_times[index]
	office_controller.attack_delay = attack_times[index]

	print(
		"Movimento: ", movement_times[index],
		"s | Ataque: ", attack_times[index], "s"
	)
	
	camera_system.generate_random_route()


func _process(delta: float) -> void:
	if night_finished:
		return

	if office_controller.game_over:
		stop_clock()
		return

	elapsed_time += delta

	current_hour = mini(
		int(elapsed_time / maxf(seconds_per_hour, 0.1)),
		6
	)

	update_clock()

	if current_hour >= 6:
		office_controller.finish_game(true)


func update_clock() -> void:
	night_label.text = "Noite %d | %02d:00" % [
		current_night,
		current_hour
	]


func stop_clock() -> void:
	night_finished = true
	set_process(false)


func register_victory() -> void:
	if current_night < MAX_NIGHTS:
		unlocked_night = maxi(
			unlocked_night,
			current_night + 1
		)
	else:
		completed_game = true

	save_progress()


func save_progress() -> void:
	var config := ConfigFile.new()

	config.set_value(
		"progress", "unlocked_night", unlocked_night
	)
	config.set_value(
		"progress", "completed_game", completed_game
	)

	var error: Error = config.save(SAVE_PATH)

	if error != OK:
		push_error(
			"Não foi possível salvar o progresso: "
			+ error_string(error)
		)


func load_progress() -> void:
	var config := ConfigFile.new()
	var error: Error = config.load(SAVE_PATH)

	# Na primeira execução ainda não existe salvamento.
	if error == ERR_FILE_NOT_FOUND:
		return

	if error != OK:
		push_warning(
			"Não foi possível carregar o progresso: "
			+ error_string(error)
		)
		return

	unlocked_night = clampi(
		int(config.get_value("progress", "unlocked_night", 1)),
		1,
		MAX_NIGHTS
	)

	completed_game = bool(
		config.get_value("progress", "completed_game", false)
	)
	
func restart_from_first_night() -> void:
	unlocked_night = 1
	current_night = 1
	completed_game = false
	save_progress()

	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		push_error("Erro ao reiniciar: " + error_string(error))
