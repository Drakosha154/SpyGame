extends Resource
class_name Puzzle
## Одна загадка = пара моделей (экипаж/шпион) с общей темой.
## Модели делаются в Blender (.glb) и похожи, но чем-то отличаются.

@export var display_name: String = ""       # название пары (для UI/отладки)
@export var category: String = ""            # общая тема (группа), напр. "Транспорт"
@export var crew_scene: PackedScene          # что видят обычные игроки
@export var spy_scene: PackedScene           # что видит шпион
@export var difficulty: int = 1              # 1 = заметно ... 3 = очень тонко
@export_multiline var note: String = ""      # чем отличаются (заметка для нас)
