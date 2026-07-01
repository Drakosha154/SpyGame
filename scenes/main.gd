extends Node
## Главная сцена — "дирижёр".
## Поток: меню входа -> 3D-лобби (все бегают) -> хост кнопкой открывает настройки
## и жмёт "Начать игру" -> цикл фаз матча.

const LOBBY_UI := preload("res://scenes/ui/LobbyUI.tscn")
const ARENA_SCENE := preload("res://scenes/Arena.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const OBJECT_DISPLAY_SCENE := preload("res://scenes/ObjectDisplay.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const VOTING_UI_SCENE := preload("res://scenes/ui/VotingUI.tscn")
const HOST_SETTINGS_SCENE := preload("res://scenes/ui/HostSettings.tscn")

var menu: Control
var arena: Node3D
var display: ObjectDisplay
var hud: Control
var voting_ui: Control
var settings: Control   # только у хоста


func _ready() -> void:
	menu = LOBBY_UI.instantiate()
	add_child(menu)
	# Как только подключились/создали сервер — заходим в мир.
	NetworkManager.hosted.connect(_enter_world)
	NetworkManager.connected_ok.connect(_enter_world)


func _enter_world() -> void:
	if menu != null:
		menu.queue_free()
		menu = null

	arena = ARENA_SCENE.instantiate()
	add_child(arena)

	display = OBJECT_DISPLAY_SCENE.instantiate()
	display.position = Vector3(0, 1, 0)
	arena.add_child(display)

	hud = HUD_SCENE.instantiate()
	add_child(hud)

	voting_ui = VOTING_UI_SCENE.instantiate()
	add_child(voting_ui)

	GameState.role_assigned.connect(_on_role_assigned)
	GameState.phase_changed.connect(_on_phase_changed)

	if multiplayer.is_server():
		# Панель настроек — только у хоста.
		settings = HOST_SETTINGS_SCENE.instantiate()
		add_child(settings)
		settings.start_requested.connect(_on_start_requested)
		settings.closed.connect(_close_settings)
		multiplayer.peer_disconnected.connect(_on_peer_left)
		_spawn_player(1)                 # свой игрок
	else:
		_request_spawn.rpc_id(1)         # просим сервер заспавнить нас


# --- Динамический спавн игроков (сервер) ---

@rpc("any_peer", "reliable")
func _request_spawn() -> void:
	if multiplayer.is_server():
		_spawn_player(multiplayer.get_remote_sender_id())

func _spawn_player(id: int) -> void:
	var players_node := arena.get_node("Players")
	if players_node.has_node(str(id)):
		return
	var p := PLAYER_SCENE.instantiate()
	p.name = str(id)
	players_node.add_child(p, true)

func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server():
		return
	var p := arena.get_node_or_null("Players/%d" % id)
	if p != null:
		p.queue_free()


# --- Роли / фазы ---

func _on_role_assigned(is_spy: bool, puzzle: Puzzle) -> void:
	display.show_puzzle(puzzle, is_spy)

func _on_phase_changed(_level: int, phase: int, _seconds: float) -> void:
	match phase:
		GameState.Phase.INSPECT:
			_teleport_local_player("ViewingRoom")
			_end_voting()
		GameState.Phase.DISCUSSION:
			_teleport_local_player("DiscussionRoom")
			_end_voting()
		GameState.Phase.VOTING:
			_teleport_local_player("DiscussionRoom")
			voting_ui.show_voting()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameState.Phase.RESULT:
			_teleport_local_player("DiscussionRoom")
			_end_voting()

func _end_voting() -> void:
	voting_ui.hide_voting()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Кнопка настроек в лобби-комнате (только хост) ---

func _process(_dt: float) -> void:
	if settings == null:
		return
	# Настройки доступны только пока не начался матч и панель закрыта.
	if GameState.current_phase != GameState.Phase.LOBBY or settings.visible:
		hud.hide_prompt()
		return
	var p := _local_player()
	var btn := arena.get_node_or_null("LobbyButton") as Node3D
	if p != null and btn != null and p.global_position.distance_to(btn.global_position) < 3.0:
		hud.show_prompt("Нажми E — настройки сервера")
		if Input.is_action_just_pressed("interact"):
			_open_settings()
	else:
		hud.hide_prompt()

func _open_settings() -> void:
	hud.hide_prompt()
	settings.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_settings() -> void:
	settings.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_start_requested(levels: int) -> void:
	_close_settings()
	NetworkManager.start_match(levels)


# --- Вспомогательное ---

func _local_player() -> Node3D:
	if arena == null:
		return null
	return arena.get_node_or_null("Players/%d" % multiplayer.get_unique_id()) as Node3D

func _teleport_local_player(room_name: String) -> void:
	var p := _local_player()
	var spawn := arena.get_node_or_null(room_name + "/Spawn") as Node3D
	if p == null or spawn == null:
		return
	var my_id := multiplayer.get_unique_id()
	var offset := float(my_id % 5) * 1.2 - 2.4
	p.global_position = spawn.global_position + Vector3(offset, 0, 0)
