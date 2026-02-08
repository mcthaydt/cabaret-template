extends Object
class_name U_FocusConfigurator

## Utility for configuring explicit focus neighbors on UI controls
##
## Godot's automatic focus neighbor calculation can be unreliable with complex layouts.
## This helper ensures predictable focus navigation by explicitly setting focus_neighbor_*
## properties on Controls.
##
## Usage:
##   var buttons: Array[Control] = [play_button, settings_button, quit_button]
##   U_FocusConfigurator.configure_vertical_focus(buttons)

## Configure vertical focus navigation (up/down) for a list of controls
##
## Sets focus_neighbor_top and focus_neighbor_bottom to create predictable vertical navigation.
## Navigation wraps: pressing up on the first control focuses the last, pressing down on the
## last control focuses the first.
##
## @param controls: Array of Control nodes in top-to-bottom order
## @param wrap_navigation: Whether to wrap navigation (default: true)
static func configure_vertical_focus(controls: Array[Control], wrap_navigation: bool = true) -> void:
	if controls.is_empty():
		push_warning("U_FocusConfigurator.configure_vertical_focus: controls array is empty")
		return

	var count: int = controls.size()

	for i in range(count):
		var control: Control = controls[i]
		if control == null:
			push_warning("U_FocusConfigurator.configure_vertical_focus: null control at index %d" % i)
			continue

		# Previous control (up direction)
		var prev_idx: int = i - 1
		if prev_idx < 0:
			prev_idx = count - 1 if wrap_navigation else -1

		if prev_idx >= 0:
			control.focus_neighbor_top = control.get_path_to(controls[prev_idx])

		# Next control (down direction)
		var next_idx: int = i + 1
		if next_idx >= count:
			next_idx = 0 if wrap_navigation else -1

		if next_idx >= 0:
			control.focus_neighbor_bottom = control.get_path_to(controls[next_idx])


## Configure horizontal focus navigation (left/right) for a list of controls
##
## Sets focus_neighbor_left and focus_neighbor_right to create predictable horizontal navigation.
## Navigation wraps: pressing left on the first control focuses the last, pressing right on the
## last control focuses the first.
##
## @param controls: Array of Control nodes in left-to-right order
## @param wrap_navigation: Whether to wrap navigation (default: true)
static func configure_horizontal_focus(controls: Array[Control], wrap_navigation: bool = true) -> void:
	if controls.is_empty():
		push_warning("U_FocusConfigurator.configure_horizontal_focus: controls array is empty")
		return

	var count: int = controls.size()

	for i in range(count):
		var control: Control = controls[i]
		if control == null:
			push_warning("U_FocusConfigurator.configure_horizontal_focus: null control at index %d" % i)
			continue

		# Previous control (left direction)
		var prev_idx: int = i - 1
		if prev_idx < 0:
			prev_idx = count - 1 if wrap_navigation else -1

		if prev_idx >= 0:
			control.focus_neighbor_left = control.get_path_to(controls[prev_idx])

		# Next control (right direction)
		var next_idx: int = i + 1
		if next_idx >= count:
			next_idx = 0 if wrap_navigation else -1

		if next_idx >= 0:
			control.focus_neighbor_right = control.get_path_to(controls[next_idx])


## Configure grid focus navigation for a 2D array of controls
##
## Sets all four focus neighbors (up/down/left/right) for controls arranged in a grid.
## Useful for settings panels, button grids, or inventory-style UIs.
##
## @param grid: 2D array of Control nodes, organized as grid[row][column]
## @param wrap_vertical: Whether to wrap vertical navigation (default: true)
## @param wrap_horizontal: Whether to wrap horizontal navigation (default: true)
static func configure_grid_focus(
	grid: Array,  # Array[Array[Control]]
	wrap_vertical: bool = true,
	wrap_horizontal: bool = true
) -> void:
	if grid.is_empty():
		push_warning("U_FocusConfigurator.configure_grid_focus: grid is empty")
		return

	var rows: int = grid.size()

	for row_idx in range(rows):
		var row: Array = grid[row_idx]
		if row.is_empty():
			continue

		var cols: int = row.size()

		for col_idx in range(cols):
			var control: Control = row[col_idx]
			if control == null:
				continue

			# Up neighbor (previous row, same column)
			var up_row: int = row_idx - 1
			if up_row < 0:
				up_row = rows - 1 if wrap_vertical else -1

			if up_row >= 0 and col_idx < grid[up_row].size():
				var up_control: Control = grid[up_row][col_idx]
				if up_control != null:
					control.focus_neighbor_top = control.get_path_to(up_control)

			# Down neighbor (next row, same column)
			var down_row: int = row_idx + 1
			if down_row >= rows:
				down_row = 0 if wrap_vertical else -1

			if down_row >= 0 and col_idx < grid[down_row].size():
				var down_control: Control = grid[down_row][col_idx]
				if down_control != null:
					control.focus_neighbor_bottom = control.get_path_to(down_control)

			# Left neighbor (same row, previous column)
			var left_col: int = col_idx - 1
			if left_col < 0:
				left_col = cols - 1 if wrap_horizontal else -1

			if left_col >= 0:
				var left_control: Control = row[left_col]
				if left_control != null:
					control.focus_neighbor_left = control.get_path_to(left_control)

			# Right neighbor (same row, next column)
			var right_col: int = col_idx + 1
			if right_col >= cols:
				right_col = 0 if wrap_horizontal else -1

			if right_col >= 0:
				var right_control: Control = row[right_col]
				if right_control != null:
					control.focus_neighbor_right = control.get_path_to(right_control)
