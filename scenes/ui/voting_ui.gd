extends Control
## Экран голосования: кнопка на каждого игрока (кроме себя). Клик — голос серверу.

@onready var title: Label = $Center/Panel/VBox/Title
@onready var list: VBoxContainer = $Center/Panel/VBox/List


func _ready() -> void:
	visible = false


# Показать голосование и построить свежие кнопки.
func show_voting() -> void:
	_build_buttons()
	title.text = "Кто шпион?"
	_set_enabled(true)
	visible = true

func hide_voting() -> void:
	visible = false


func _build_buttons() -> void:
	for c in list.get_children():
		c.queue_free()
	var me := multiplayer.get_unique_id()
	for id in NetworkManager.players:
		if id == me:
			continue   # за себя не голосуем
		var b := Button.new()
		b.text = str(NetworkManager.players[id])
		b.pressed.connect(_on_vote.bind(id))
		list.add_child(b)


func _on_vote(target_id: int) -> void:
	GameState.cast_vote(target_id)
	title.text = "Голос за: %s" % str(NetworkManager.players[target_id])
	_set_enabled(false)   # один голос на уровень


func _set_enabled(on: bool) -> void:
	for b in list.get_children():
		b.disabled = not on
