extends Resource
class_name Puzzle
## Одна загадка = пара моделей. Экипаж видит одну, шпион — другую.
## Модели делаются в Blender (.glb) и имеют общую тему, но чем-то отличаются.

@export var display_name: String = ""          # название (для UI/отладки)
@export var crew_scene: PackedScene             # модель для обычных игроков
@export var spy_scene: PackedScene              # модель для шпиона
@export_multiline var note: String = ""         # чем отличаются (заметка для нас)
