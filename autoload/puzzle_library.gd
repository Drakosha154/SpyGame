extends Node
## Каталог всех загадок. Автозагрузка — доступен как PuzzleLibrary из любого места.
## Пока собираем список в коде. Позже можно завести .tres-файлы, чтобы художник
## создавал загадки прямо в редакторе, без программиста.

# Заглушки-модели. Когда будут модели из Blender — поменяй пути на .glb.
const CREW_CUBES := preload("res://assets/models/crew_many_cubes.tscn")
const SPY_CUBE := preload("res://assets/models/spy_big_cube.tscn")

var puzzles: Array[Puzzle] = []


func _ready() -> void:
	var cubes := Puzzle.new()
	cubes.display_name = "Кубики"
	cubes.crew_scene = CREW_CUBES
	cubes.spy_scene = SPY_CUBE
	cubes.note = "Экипаж видит много маленьких кубиков, шпион — один большой."
	puzzles.append(cubes)

	# Сюда добавляй новые загадки той же схемой (позже — из Blender).


func random_puzzle() -> Puzzle:
	return puzzles[randi() % puzzles.size()]
