extends Control
## Верхняя плашка: уровень N/всего, фаза, обратный отсчёт.
## По центру — итог уровня (кто победил и кто был шпионом) и сообщение о ничьей.
## Роль игрока НЕ показываем.

@onready var top_label: Label = $TopLabel
@onready var center_label: Label = $CenterLabel
@onready var interact_prompt: Label = $InteractPrompt

var time_left: float = 0.0
var phase_name: String = ""


func _ready() -> void:
	center_label.text = ""
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.level_resolved.connect(_on_level_resolved)
	GameState.revote_started.connect(_on_revote_started)


func _on_phase_changed(level: int, phase: int, seconds: float) -> void:
	phase_name = _phase_name(phase)
	time_left = seconds
	center_label.text = ""
	_update_top(level)


# Итог уровня: кто победил и кто был шпионом.
func _on_level_resolved(spy_name: String, _accused_name: String, crew_won: bool, _crew_score: int, _spy_score: int) -> void:
	var headline := "Экипаж победил!" if crew_won else "Победил шпион!"
	center_label.text = "%s\nШпионом был: %s" % [headline, spy_name]


func _on_revote_started(tied_names: String) -> void:
	center_label.text = "Ничья: %s\nПереголосование!" % tied_names


func _process(delta: float) -> void:
	if time_left > 0.0:
		time_left = max(0.0, time_left - delta)
		_update_top(GameState.current_level)


func _update_top(level: int) -> void:
	top_label.text = "Уровень %d/%d — %s — %d" % [
		level, GameState.total_levels, phase_name, int(ceil(time_left))]


func show_prompt(text: String) -> void:
	interact_prompt.text = text

func hide_prompt() -> void:
	interact_prompt.text = ""


func _phase_name(phase: int) -> String:
	match phase:
		GameState.Phase.INSPECT: return "Осмотр"
		GameState.Phase.DISCUSSION: return "Обсуждение"
		GameState.Phase.VOTING: return "Голосование"
		GameState.Phase.RESULT: return "Итог"
		_: return "Лобби"
