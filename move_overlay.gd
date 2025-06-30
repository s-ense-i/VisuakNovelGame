extends TileMap

## يرسم البلاطات في الأماكن المسموح بها
func draw_cells(cells: Array) -> void:
	clear()
	for cell in cells:
		set_cell(0, cell, 0, Vector2i(0, 0))  # ← بلاطة زرقاء
