extends Control
## Панель настроек сервера. Открывает хост из лобби-комнаты (кнопкой).

signal start_requested(levels: int, difficulty: int)
signal closed

@onready var spin: SpinBox = $Center/Panel/VBox/LevelsRow/LevelsSpin
@onready var diff_option: OptionButton = $Center/Panel/VBox/DifficultyRow/DifficultyOption


func _ready() -> void:
	visible = false
	# id == 0 "любая", иначе 1..3 — совпадает со значением difficulty у загадок.
	diff_option.add_item("Любая", 0)
	diff_option.add_item("Лёгкая (заметно)", 1)
	diff_option.add_item("Средняя", 2)
	diff_option.add_item("Сложная (тонко)", 3)
	diff_option.selected = 0

	$Center/Panel/VBox/StartButton.pressed.connect(_on_start)
	$Center/Panel/VBox/CloseButton.pressed.connect(_on_close)


func open() -> void:
	visible = true


func _on_start() -> void:
	start_requested.emit(int(spin.value), diff_option.get_selected_id())


func _on_close() -> void:
	closed.emit()
