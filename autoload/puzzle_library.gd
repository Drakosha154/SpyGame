extends Node
## Каталог загадок. Автозагрузка — доступен как PuzzleLibrary из любого места.
##
## Все предметы описаны ДАННЫМИ в PUZZLE_DATA: словарь по категориям, а в каждой —
## список пар "экипаж/шпион". Категория = общая тема этих моделей.
##
## ЧТОБЫ ДОБАВИТЬ ПРЕДМЕТ: допиши строчку в нужную категорию (или заведи новую).
## Размер модели подгоняется автоматически (в ObjectDisplay), масштаб указывать не надо.

const PUZZLE_DATA := {
	"Кубики": [
		{
			"name": "Много / один кубик",
			"crew": "res://assets/models/crew_many_cubes.tscn",
			"spy": "res://assets/models/spy_big_cube.tscn",
			"difficulty": 1,
			"note": "Много маленьких кубиков против одного большого.",
		},
	],

	"Кости": [
		{
			"name": "Красная / оранжевая кость",
			"crew": "res://assets/models/dice/dice_red/dice_red.fbx",
			"spy": "res://assets/models/dice/dice_orange/dice_orange.fbx",
			"difficulty": 2,
			"note": "Красный против оранжевого.",
		},
		{
			"name": "Синяя / тёмно-синяя кость",
			"crew": "res://assets/models/dice/dice_blue/dice_blue.fbx",
			"spy": "res://assets/models/dice/dice_blueDark/dice_blueDark.fbx",
			"difficulty": 3,
			"note": "Очень близкие оттенки синего.",
		},
		{
			"name": "Зелёная / жёлтая кость",
			"crew": "res://assets/models/dice/dice_green/dice_green.fbx",
			"spy": "res://assets/models/dice/dice_yellow/dice_yellow.fbx",
			"difficulty": 2,
		},
		{
			"name": "Фиолетовая / синяя кость",
			"crew": "res://assets/models/dice/dice_purple/dice_purple.fbx",
			"spy": "res://assets/models/dice/dice_blue/dice_blue.fbx",
			"difficulty": 3,
		},
		{
			"name": "Белая / жёлтая кость",
			"crew": "res://assets/models/dice/dice_white/dice_white.fbx",
			"spy": "res://assets/models/dice/dice_yellow/dice_yellow.fbx",
			"difficulty": 3,
			"note": "Белый против бледно-жёлтого — очень тонко.",
		},
	],

	"Японская лавка": [
		{
			"name": "Прилавок / плита",
			"crew": "res://assets/models/japan/counterA/counter_a.tscn",
			"spy": "res://assets/models/japan/stove/stove.tscn",
			"difficulty": 2,
		},
		{
			"name": "Рамен / ящик пива",
			"crew": "res://assets/models/japan/ramen/ramen.tscn",
			"spy": "res://assets/models/japan/beer/beer_crate_green.tscn",
			"difficulty": 2,
		},
		{
			"name": "Лайтбокс / баннер",
			"crew": "res://assets/models/japan/lightBox/light_box.tscn",
			"spy": "res://assets/models/japan/banner/standing_banner.tscn",
			"difficulty": 2,
		},
		{
			"name": "Нож / ступенька",
			"crew": "res://assets/models/japan/knife/knife.tscn",
			"spy": "res://assets/models/japan/doorStep/door_step.tscn",
			"difficulty": 2,
			"note": "Слабая пара по смыслу — при желании перепарь.",
		},
	],

	"Деревня": [
		{
			"name": "Дом / большой дом",
			"crew": "res://assets/models/village/house_single/house_single.tscn",
			"spy": "res://assets/models/village/big_house/big_house.tscn",
			"difficulty": 1,
		},
		{
			"name": "Забор / указатель",
			"crew": "res://assets/models/village/fence/fence.tscn",
			"spy": "res://assets/models/village/signpost/signpost.tscn",
			"difficulty": 2,
		},
		{
			"name": "Кружка / колодец",
			"crew": "res://assets/models/village/mug/mug.tscn",
			"spy": "res://assets/models/village/well/village_well.tscn",
			"difficulty": 2,
		},
	],

	"Разное": [
		{
			"name": "Кубики / Санта",
			"crew": "res://assets/models/crew_many_cubes.tscn",
			"spy": "res://assets/models/santa/santa.tscn",
			"difficulty": 1,
		},
	],
}

# Готовый плоский список всех загадок (в порядке из PUZZLE_DATA — одинаков у всех).
var puzzles: Array[Puzzle] = []


func _ready() -> void:
	_build_from_data()


func _build_from_data() -> void:
	puzzles.clear()
	for category in PUZZLE_DATA:
		for entry in PUZZLE_DATA[category]:
			var p := _make_puzzle(category, entry)
			if p != null:
				puzzles.append(p)
	if puzzles.is_empty():
		push_warning("PuzzleLibrary: не загружено ни одной загадки — проверь пути в PUZZLE_DATA.")
	else:
		print("PuzzleLibrary: загружено загадок — %d (категорий: %d)" % [puzzles.size(), PUZZLE_DATA.size()])


func _make_puzzle(category: String, entry: Dictionary) -> Puzzle:
	var crew_path: String = entry.get("crew", "")
	var spy_path: String = entry.get("spy", "")

	var crew_scene: PackedScene = null
	var spy_scene: PackedScene = null
	if ResourceLoader.exists(crew_path):
		crew_scene = load(crew_path) as PackedScene
	if ResourceLoader.exists(spy_path):
		spy_scene = load(spy_path) as PackedScene

	if crew_scene == null or spy_scene == null:
		push_warning("PuzzleLibrary: пропущена загадка '%s' — не найдена одна из моделей." % entry.get("name", "?"))
		return null

	var p := Puzzle.new()
	p.display_name = entry.get("name", category)
	p.category = category
	p.crew_scene = crew_scene
	p.spy_scene = spy_scene
	p.difficulty = int(entry.get("difficulty", 1))
	p.note = entry.get("note", "")
	return p


# --- Выбор загадок ---

func random_puzzle() -> Puzzle:
	return puzzles[randi() % puzzles.size()]

func by_category(category: String) -> Array:
	return puzzles.filter(func(p): return p.category == category)

func by_difficulty(difficulty: int) -> Array:
	return puzzles.filter(func(p): return p.difficulty == difficulty)

func categories() -> Array:
	return PUZZLE_DATA.keys()
