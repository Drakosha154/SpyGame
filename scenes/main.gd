extends Node
## Главная сцена — "дирижёр".
## Вход -> 3D-лобби -> хост кнопкой открывает настройки и стартует матч -> фазы.
## Голосование: целишься камерой в игрока и жмёшь ЛКМ; над головами — счёт голосов.

const LOBBY_UI := preload("res://scenes/ui/LobbyUI.tscn")
const ARENA_SCENE := preload("res://scenes/Arena.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const OBJECT_DISPLAY_SCENE := preload("res://scenes/ObjectDisplay.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const HOST_SETTINGS_SCENE := preload("res://scenes/ui/HostSettings.tscn")

var menu: Control
var arena: Node3D
var display: ObjectDisplay
var hud: Control
var settings: Control   # только у хоста


func _ready() -> void:
	menu = LOBBY_UI.instantiate()
	add_child(menu)
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

	GameState.role_assigned.connect(_on_role_assigned)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.vote_counts_changed.connect(_on_vote_counts)

	if multiplayer.is_server():
		settings = HOST_SETTINGS_SCENE.instantiate()
		add_child(settings)
		settings.start_requested.connect(_on_start_requested)
		settings.closed.connect(_close_settings)
		multiplayer.peer_disconnected.connect(_on_peer_left)
		_spawn_player(1)
	else:
		_request_spawn.rpc_id(1)


# --- Спавн игроков (сервер) ---

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
			_set_vote_labels(false)
		GameState.Phase.DISCUSSION:
			_teleport_local_player("DiscussionRoom")
			_set_vote_labels(false)
		GameState.Phase.VOTING:
			_teleport_local_player("DiscussionRoom")
			_set_vote_labels(true)
		GameState.Phase.RESULT:
			_teleport_local_player("DiscussionRoom")
			_set_vote_labels(false)
	# Курсор всегда захвачен (голосуем прицеливанием, не мышью).
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Показать/скрыть 3D-метки голосов над всеми игроками.
func _set_vote_labels(on: bool) -> void:
	var players_node := arena.get_node_or_null("Players")
	if players_node == null:
		return
	for p in players_node.get_children():
		if on:
			p.show_vote_label()
			p.set_vote_count(0)
		else:
			p.hide_vote_label()

# Пришли свежие числа голосов — проставляем над головами.
func _on_vote_counts(counts: Dictionary) -> void:
	var players_node := arena.get_node_or_null("Players")
	if players_node == null:
		return
	for p in players_node.get_children():
		var id := str(p.name).to_int()
		p.set_vote_count(int(counts.get(id, 0)))


# --- Каждый кадр: прицел при голосовании / кнопка настроек хоста ---

func _process(_dt: float) -> void:
	if arena == null:
		return
	if GameState.current_phase == GameState.Phase.VOTING:
		hud.show_crosshair(true)
		_update_vote_aim()
	else:
		hud.show_crosshair(false)
		_update_host_button()


func _update_vote_aim() -> void:
	var p := _local_player()
	if p == null:
		hud.hide_prompt()
		return
	var tid: int = p.get_aim_target_id()
	if tid != -1:
		hud.show_prompt("ЛКМ — голос за: %s" % str(NetworkManager.players.get(tid, "?")))
	else:
		hud.show_prompt("Наведись на подозреваемого")


func _update_host_button() -> void:
	if settings == null:
		hud.hide_prompt()
		return
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


# --- Настройки хоста ---

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
