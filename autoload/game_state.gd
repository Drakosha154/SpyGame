extends Node
## GameState — "мозг" игры. Сервер раздаёт роли, ведёт фазы и считает голоса.

enum Phase { LOBBY, INSPECT, DISCUSSION, VOTING, RESULT }
var current_phase: Phase = Phase.LOBBY

# Длительности фаз в секундах (подстраивай под вкус).
const INSPECT_TIME := 6.0
const DISCUSSION_TIME := 6.0
const VOTING_TIME := 15.0
const RESULT_TIME := 10.0

var total_levels: int = 99
var current_level: int = 0

# СЕКРЕТ СЕРВЕРА: кто шпион на этом уровне.
var spy_id: int = -1

# Что знает про СЕБЯ локальный игрок:
var my_is_spy: bool = false
var current_puzzle: Puzzle = null

# Только на сервере: голоса { голосующий_id: за_кого_id } и общий счёт.
var _server_votes: Dictionary = {}
var crew_score: int = 0
var spy_score: int = 0

signal role_assigned(is_spy: bool, puzzle: Puzzle)
signal phase_changed(level: int, phase: int, seconds: float)
signal level_resolved(spy_name: String, accused_name: String, crew_won: bool, crew_score: int, spy_score: int)
signal match_over(winner: String, crew_score: int, spy_score: int)
signal revote_started(tied_names: String)


# --- СЕРВЕР: весь матч ---

func server_start_match() -> void:
	if not multiplayer.is_server():
		return
	current_level = 0
	crew_score = 0
	spy_score = 0
	_server_match_loop()

func _server_match_loop() -> void:
	while not is_match_over():
		current_level += 1
		_server_setup_level()
		await _server_phase(Phase.INSPECT, INSPECT_TIME)
		await _server_phase(Phase.DISCUSSION, DISCUSSION_TIME)
		var accused: int = await _server_run_voting()
		# Сначала входим в фазу итога, ПОТОМ показываем результат —
		# иначе смена фазы затрёт текст итога.
		_apply_phase.rpc(current_level, Phase.RESULT, RESULT_TIME)
		_server_apply_outcome(accused)
		await get_tree().create_timer(RESULT_TIME).timeout

	# Матч закончился — объявляем общего победителя.
	var winner: String
	if crew_score > spy_score:
		winner = "Экипаж"
	elif spy_score > crew_score:
		winner = "Шпионы"
	else:
		winner = "Ничья"
	print("[Сервер] Матч окончен. Победитель: %s" % winner)
	_apply_match_over.rpc(winner, crew_score, spy_score)

func _server_setup_level() -> void:
	var idx := randi() % PuzzleLibrary.puzzles.size()
	spy_id = _pick_spy()
	print("[Сервер] Уровень %d, шпион = peer %d" % [current_level, spy_id])
	for id in NetworkManager.players:
		var this_is_spy: bool = (id == spy_id)
		if id == multiplayer.get_unique_id():
			receive_role(this_is_spy, idx)
		else:
			receive_role.rpc_id(id, this_is_spy, idx)

func _server_phase(phase: Phase, seconds: float) -> void:
	_apply_phase.rpc(current_level, phase, seconds)
	await get_tree().create_timer(seconds).timeout

# Провести голосование. При ничьей — переголосование (до 3 туров),
# на последнем туре ничью решает жребий. Возвращает id обвинённого.
func _server_run_voting() -> int:
	for attempt in 3:
		_server_votes.clear()
		await _server_phase(Phase.VOTING, VOTING_TIME)
		var res := _tally_votes()
		if not res["tie"]:
			return int(res["accused"])
		# Ничья.
		if attempt == 2:
			var tied: Array = res["tied"]
			return int(tied[randi() % tied.size()])   # жребий на последнем туре
		# Объявляем переголосование и даём пару секунд прочитать.
		_apply_revote.rpc(_names_of(res["tied"]))
		await get_tree().create_timer(3.0).timeout
	return -1   # сюда не доходим


# Подсчёт голосов. Возвращает { tie, accused, tied }.
func _tally_votes() -> Dictionary:
	var tally: Dictionary = {}
	for voter in _server_votes:
		var t: int = _server_votes[voter]
		tally[t] = int(tally.get(t, 0)) + 1

	if tally.is_empty():
		return {"tie": false, "accused": -1, "tied": []}   # никто не голосовал → шпион ушёл

	var best := 0
	for t in tally:
		if tally[t] > best:
			best = tally[t]

	var tied: Array = []
	for t in tally:
		if tally[t] == best:
			tied.append(t)

	if tied.size() == 1:
		return {"tie": false, "accused": tied[0], "tied": tied}
	return {"tie": true, "accused": -1, "tied": tied}


# Определить победителя уровня, начислить очко, разослать итог.
func _server_apply_outcome(accused: int) -> void:
	var crew_won := (accused == spy_id)
	if crew_won:
		crew_score += 1
	else:
		spy_score += 1
	var spy_name: String = NetworkManager.players.get(spy_id, "?")
	var accused_name: String = NetworkManager.players.get(accused, "никто")
	_apply_result.rpc(spy_name, accused_name, crew_won, crew_score, spy_score)


# Имена по списку id — для сообщения о ничьей.
func _names_of(ids: Array) -> String:
	var names: Array = []
	for id in ids:
		names.append(str(NetworkManager.players.get(id, "?")))
	return ", ".join(names)

func _pick_spy() -> int:
	var ids: Array = NetworkManager.players.keys()
	return ids[randi() % ids.size()]

func is_match_over() -> bool:
	return current_level >= total_levels


# --- Голосование (вызывается из UI) ---

func cast_vote(target_id: int) -> void:
	if multiplayer.is_server():
		_server_votes[multiplayer.get_unique_id()] = target_id
	else:
		submit_vote.rpc_id(1, target_id)

# Клиент присылает голос серверу.
@rpc("any_peer", "reliable")
func submit_vote(target_id: int) -> void:
	if not multiplayer.is_server():
		return
	var voter := multiplayer.get_remote_sender_id()
	_server_votes[voter] = target_id


# --- КЛИЕНТ: приходит от сервера ---

@rpc("authority", "reliable")
func receive_role(is_spy_role: bool, puzzle_index: int) -> void:
	my_is_spy = is_spy_role
	current_puzzle = PuzzleLibrary.puzzles[puzzle_index]
	print("[Я] Роль на этом уровне: %s" % ("ШПИОН" if my_is_spy else "экипаж"))
	role_assigned.emit(my_is_spy, current_puzzle)

@rpc("authority", "call_local", "reliable")
func _apply_phase(level: int, phase: int, seconds: float) -> void:
	current_level = level
	current_phase = phase
	phase_changed.emit(level, phase, seconds)

@rpc("authority", "call_local", "reliable")
func _apply_result(spy_name: String, accused_name: String, crew_won: bool, cscore: int, sscore: int) -> void:
	crew_score = cscore
	spy_score = sscore
	level_resolved.emit(spy_name, accused_name, crew_won, cscore, sscore)

@rpc("authority", "call_local", "reliable")
func _apply_match_over(winner: String, cscore: int, sscore: int) -> void:
	current_phase = Phase.LOBBY
	match_over.emit(winner, cscore, sscore)

@rpc("authority", "call_local", "reliable")
func _apply_revote(tied_names: String) -> void:
	revote_started.emit(tied_names)
