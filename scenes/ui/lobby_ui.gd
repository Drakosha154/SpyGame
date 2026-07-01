extends Control
## Экран входа: имя, IP, Создать сервер / Подключиться.
## После успеха Main убирает это меню и переносит игрока в 3D-лобби.

@onready var name_edit: LineEdit = $ConnectPanel/NameEdit
@onready var ip_edit: LineEdit = $ConnectPanel/IPEdit
@onready var host_button: Button = $ConnectPanel/HostButton
@onready var join_button: Button = $ConnectPanel/JoinButton
@onready var status_label: Label = $ConnectPanel/StatusLabel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.connection_failed.connect(_on_connection_failed)


func _on_host_pressed() -> void:
	if not NetworkManager.host_game(_get_name()):
		status_label.text = "Не удалось создать сервер (порт занят?)."

func _on_join_pressed() -> void:
	status_label.text = "Подключение..."
	if not NetworkManager.join_game(ip_edit.text.strip_edges(), _get_name()):
		status_label.text = "Неверный адрес."

func _on_connection_failed() -> void:
	status_label.text = "Не удалось подключиться. Проверь IP и что сервер запущен."


func _get_name() -> String:
	var n := name_edit.text.strip_edges()
	return n if n != "" else "Игрок"
