extends Control
## Панель настроек сервера. Открывает хост из лобби-комнаты (кнопкой).

signal start_requested(levels: int)
signal closed

@onready var spin: SpinBox = $Center/Panel/VBox/LevelsRow/LevelsSpin


func _ready() -> void:
	visible = false
	$Center/Panel/VBox/StartButton.pressed.connect(_on_start)
	$Center/Panel/VBox/CloseButton.pressed.connect(_on_close)


func open() -> void:
	visible = true


func _on_start() -> void:
	start_requested.emit(int(spin.value))


func _on_close() -> void:
	closed.emit()
