extends Node
## NetworkManager — управляет сетью: создать сервер (host) или подключиться (join),
## и держит синхронный у всех список игроков. Автозагрузка.

const DEFAULT_PORT := 24545
const MAX_PLAYERS := 6

# Список игроков: peer_id -> имя. У сервера id всегда 1.
var players: Dictionary = {}
var my_name: String = "Игрок"

# Сигналы для UI.
signal player_list_changed
signal connection_failed
signal connected_ok
signal hosted
signal game_started


func _ready() -> void:
	# Подписываемся на сетевые события один раз.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- Запуск ---

func host_game(player_name: String) -> bool:
	my_name = player_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if err != OK:
		push_error("Не удалось создать сервер (код %d)" % err)
		return false
	multiplayer.multiplayer_peer = peer
	# Сервер — тоже игрок, id = 1.
	players[1] = my_name
	player_list_changed.emit()
	hosted.emit()
	print("Сервер запущен на порту %d" % DEFAULT_PORT)
	return true


func join_game(ip: String, player_name: String) -> bool:
	my_name = player_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, DEFAULT_PORT)
	if err != OK:
		push_error("Не удалось подключиться (код %d)" % err)
		connection_failed.emit()
		return false
	multiplayer.multiplayer_peer = peer
	print("Подключаемся к %s..." % ip)
	return true


# --- Сетевые события ---

func _on_peer_connected(id: int) -> void:
	# Новый peer подключился. Имя узнаем, когда он сам его пришлёт (register_player).
	print("Peer подключился: %d" % id)

func _on_peer_disconnected(id: int) -> void:
	# Сервер убирает ушедшего и рассылает обновлённый список.
	if multiplayer.is_server():
		players.erase(id)
		_broadcast_players()
	print("Peer отключился: %d" % id)

func _on_connected_to_server() -> void:
	# Мы (клиент) успешно подключились — сообщаем серверу своё имя.
	register_player.rpc_id(1, my_name)
	connected_ok.emit()

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	# Сервер закрылся — сбрасываем состояние.
	players.clear()
	multiplayer.multiplayer_peer = null
	player_list_changed.emit()


# --- Синхронизация списка игроков ---

# Клиент вызывает ЭТО на сервере, чтобы представиться.
@rpc("any_peer", "reliable")
func register_player(player_name: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	players[id] = player_name
	_broadcast_players()

# Сервер рассылает актуальный список всем.
func _broadcast_players() -> void:
	if not multiplayer.is_server():
		return
	_update_players.rpc(players)   # всем остальным peer'ам
	player_list_changed.emit()      # самому серверу

# Приходит клиентам от сервера.
@rpc("authority", "reliable")
func _update_players(new_players: Dictionary) -> void:
	players = new_players
	player_list_changed.emit()


# --- Старт матча ---

# Хост запускает матч (из настроек в лобби-комнате), передавая число уровней.
func start_match(levels: int) -> void:
	if multiplayer.is_server():
		_start_game.rpc(levels)

# call_local — выполнится и на сервере, и на всех клиентах.
@rpc("authority", "call_local", "reliable")
func _start_game(levels: int) -> void:
	GameState.total_levels = levels
	if multiplayer.is_server():
		GameState.server_start_match()
	game_started.emit()
