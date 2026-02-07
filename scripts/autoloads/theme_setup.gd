extends Node
## ThemeSetup -- Creates and applies a polished dark sci-fi theme to the entire game.
## Called once at startup from GameManager.
##
## Design language: Dark military/industrial aesthetic inspired by classic M.A.X.
## - Deep blue-gray backgrounds
## - Cyan/teal accent highlights
## - High-contrast text on dark surfaces
## - Subtle beveled edges on interactive elements
## - Semi-transparent overlays

const COLOR_BG_DARK := Color(0.06, 0.08, 0.12, 1.0)         # Deepest background
const COLOR_BG := Color(0.09, 0.11, 0.16, 1.0)              # Normal panel background
const COLOR_BG_LIGHT := Color(0.12, 0.15, 0.22, 1.0)        # Lighter panel/hover
const COLOR_BG_HOVER := Color(0.15, 0.19, 0.28, 1.0)        # Hover highlight
const COLOR_BG_PRESSED := Color(0.08, 0.10, 0.15, 1.0)      # Pressed state
const COLOR_BORDER := Color(0.20, 0.25, 0.35, 1.0)          # Default border
const COLOR_BORDER_FOCUS := Color(0.30, 0.65, 0.85, 1.0)    # Focused border (cyan)
const COLOR_ACCENT := Color(0.30, 0.70, 0.90, 1.0)          # Primary accent (cyan)
const COLOR_ACCENT_DIM := Color(0.20, 0.45, 0.65, 1.0)      # Dimmed accent
const COLOR_TEXT := Color(0.88, 0.90, 0.95, 1.0)             # Primary text
const COLOR_TEXT_MUTED := Color(0.50, 0.55, 0.65, 1.0)       # Muted/secondary text
const COLOR_TEXT_BRIGHT := Color(1.0, 1.0, 1.0, 1.0)         # Bright white text
const COLOR_BUTTON := Color(0.12, 0.16, 0.24, 1.0)          # Button normal
const COLOR_BUTTON_HOVER := Color(0.16, 0.22, 0.34, 1.0)    # Button hover
const COLOR_BUTTON_PRESSED := Color(0.10, 0.13, 0.20, 1.0)  # Button pressed
const COLOR_BUTTON_DISABLED := Color(0.08, 0.10, 0.14, 1.0) # Button disabled
const COLOR_SEPARATOR := Color(0.18, 0.22, 0.30, 0.8)       # Separator line
const COLOR_SELECTION := Color(0.20, 0.50, 0.70, 0.5)       # Selection highlight
const COLOR_SCROLLBAR := Color(0.18, 0.22, 0.30, 1.0)       # Scrollbar track
const COLOR_SCROLLBAR_GRAB := Color(0.30, 0.38, 0.50, 1.0)  # Scrollbar grabber
const COLOR_GREEN := Color(0.25, 0.80, 0.35, 1.0)           # Positive/success
const COLOR_RED := Color(0.90, 0.25, 0.20, 1.0)             # Negative/danger
const COLOR_YELLOW := Color(0.95, 0.80, 0.20, 1.0)          # Warning/gold

const CORNER_RADIUS := 4
const BORDER_WIDTH := 1
const CONTENT_MARGIN := 8


static func create_theme() -> Theme:
	var theme := Theme.new()

	# Default font color
	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.3))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)

	# --- Button ---
	theme.set_stylebox("normal", "Button", _make_button_style(COLOR_BUTTON, COLOR_BORDER))
	theme.set_stylebox("hover", "Button", _make_button_style(COLOR_BUTTON_HOVER, COLOR_ACCENT_DIM))
	theme.set_stylebox("pressed", "Button", _make_button_style(COLOR_BUTTON_PRESSED, COLOR_ACCENT))
	theme.set_stylebox("disabled", "Button", _make_button_style(COLOR_BUTTON_DISABLED, Color(0.12, 0.14, 0.18, 1.0)))
	theme.set_stylebox("focus", "Button", _make_button_style(COLOR_BUTTON, COLOR_BORDER_FOCUS))
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", COLOR_TEXT_BRIGHT)
	theme.set_color("font_pressed_color", "Button", COLOR_ACCENT)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	theme.set_color("font_focus_color", "Button", COLOR_TEXT_BRIGHT)

	# --- PanelContainer ---
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BG
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(BORDER_WIDTH)
	panel_style.set_corner_radius_all(CORNER_RADIUS + 2)
	panel_style.set_content_margin_all(CONTENT_MARGIN + 4)
	panel_style.shadow_color = Color(0, 0, 0, 0.4)
	panel_style.shadow_size = 4
	panel_style.shadow_offset = Vector2(2, 2)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# --- Panel ---
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = COLOR_BG
	panel_bg.border_color = COLOR_BORDER
	panel_bg.set_border_width_all(BORDER_WIDTH)
	panel_bg.set_corner_radius_all(CORNER_RADIUS)
	theme.set_stylebox("panel", "Panel", panel_bg)

	# --- LineEdit ---
	var line_normal := StyleBoxFlat.new()
	line_normal.bg_color = COLOR_BG_DARK
	line_normal.border_color = COLOR_BORDER
	line_normal.set_border_width_all(BORDER_WIDTH)
	line_normal.set_corner_radius_all(CORNER_RADIUS)
	line_normal.set_content_margin_all(6)
	theme.set_stylebox("normal", "LineEdit", line_normal)
	var line_focus := line_normal.duplicate()
	line_focus.border_color = COLOR_BORDER_FOCUS
	theme.set_stylebox("focus", "LineEdit", line_focus)
	theme.set_color("font_color", "LineEdit", COLOR_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", COLOR_TEXT_MUTED)
	theme.set_color("caret_color", "LineEdit", COLOR_ACCENT)
	theme.set_color("selection_color", "LineEdit", COLOR_SELECTION)

	# --- SpinBox inherits LineEdit styling ---

	# --- CheckBox / CheckButton ---
	theme.set_color("font_color", "CheckBox", COLOR_TEXT)
	theme.set_color("font_hover_color", "CheckBox", COLOR_TEXT_BRIGHT)
	theme.set_color("font_pressed_color", "CheckBox", COLOR_ACCENT)

	# --- OptionButton ---
	theme.set_stylebox("normal", "OptionButton", _make_button_style(COLOR_BUTTON, COLOR_BORDER))
	theme.set_stylebox("hover", "OptionButton", _make_button_style(COLOR_BUTTON_HOVER, COLOR_ACCENT_DIM))
	theme.set_stylebox("pressed", "OptionButton", _make_button_style(COLOR_BUTTON_PRESSED, COLOR_ACCENT))
	theme.set_stylebox("focus", "OptionButton", _make_button_style(COLOR_BUTTON, COLOR_BORDER_FOCUS))
	theme.set_color("font_color", "OptionButton", COLOR_TEXT)
	theme.set_color("font_hover_color", "OptionButton", COLOR_TEXT_BRIGHT)
	theme.set_color("font_pressed_color", "OptionButton", COLOR_ACCENT)

	# --- ItemList ---
	var itemlist_bg := StyleBoxFlat.new()
	itemlist_bg.bg_color = COLOR_BG_DARK
	itemlist_bg.border_color = COLOR_BORDER
	itemlist_bg.set_border_width_all(BORDER_WIDTH)
	itemlist_bg.set_corner_radius_all(CORNER_RADIUS)
	itemlist_bg.set_content_margin_all(4)
	theme.set_stylebox("panel", "ItemList", itemlist_bg)
	theme.set_color("font_color", "ItemList", COLOR_TEXT)
	theme.set_color("font_selected_color", "ItemList", COLOR_TEXT_BRIGHT)
	var itemlist_selected := StyleBoxFlat.new()
	itemlist_selected.bg_color = COLOR_SELECTION
	itemlist_selected.set_corner_radius_all(2)
	theme.set_stylebox("selected", "ItemList", itemlist_selected)
	theme.set_stylebox("selected_focus", "ItemList", itemlist_selected)

	# --- ScrollContainer ---
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0, 0, 0, 0)
	theme.set_stylebox("panel", "ScrollContainer", scroll_bg)

	# --- VScrollBar / HScrollBar ---
	var scrollbar_bg := StyleBoxFlat.new()
	scrollbar_bg.bg_color = COLOR_SCROLLBAR
	scrollbar_bg.set_corner_radius_all(4)
	scrollbar_bg.set_content_margin_all(2)
	theme.set_stylebox("scroll", "VScrollBar", scrollbar_bg)
	theme.set_stylebox("scroll", "HScrollBar", scrollbar_bg)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = COLOR_SCROLLBAR_GRAB
	grabber.set_corner_radius_all(4)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber", "HScrollBar", grabber)
	var grabber_highlight := grabber.duplicate()
	grabber_highlight.bg_color = COLOR_ACCENT_DIM
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber_highlight)
	theme.set_stylebox("grabber_highlight", "HScrollBar", grabber_highlight)
	var grabber_pressed := grabber.duplicate()
	grabber_pressed.bg_color = COLOR_ACCENT
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber_pressed)
	theme.set_stylebox("grabber_pressed", "HScrollBar", grabber_pressed)

	# --- HSeparator ---
	var separator := StyleBoxFlat.new()
	separator.bg_color = COLOR_SEPARATOR
	separator.set_content_margin_all(0)
	separator.content_margin_top = 4
	separator.content_margin_bottom = 4
	theme.set_stylebox("separator", "HSeparator", separator)
	theme.set_constant("separation", "HSeparator", 2)

	# --- TabContainer ---
	var tab_panel := StyleBoxFlat.new()
	tab_panel.bg_color = COLOR_BG
	tab_panel.border_color = COLOR_BORDER
	tab_panel.set_border_width_all(BORDER_WIDTH)
	tab_panel.set_corner_radius_all(CORNER_RADIUS)
	tab_panel.set_content_margin_all(8)
	theme.set_stylebox("panel", "TabContainer", tab_panel)

	# --- ProgressBar ---
	var prog_bg := StyleBoxFlat.new()
	prog_bg.bg_color = COLOR_BG_DARK
	prog_bg.border_color = COLOR_BORDER
	prog_bg.set_border_width_all(BORDER_WIDTH)
	prog_bg.set_corner_radius_all(3)
	theme.set_stylebox("background", "ProgressBar", prog_bg)
	var prog_fill := StyleBoxFlat.new()
	prog_fill.bg_color = COLOR_ACCENT
	prog_fill.set_corner_radius_all(2)
	theme.set_stylebox("fill", "ProgressBar", prog_fill)
	theme.set_color("font_color", "ProgressBar", COLOR_TEXT_BRIGHT)

	# --- HSlider ---
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = COLOR_SCROLLBAR
	slider_bg.set_corner_radius_all(3)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_bg)
	var slider_grabber_area := StyleBoxFlat.new()
	slider_grabber_area.bg_color = COLOR_ACCENT_DIM
	slider_grabber_area.set_corner_radius_all(3)
	slider_grabber_area.content_margin_top = 4
	slider_grabber_area.content_margin_bottom = 4
	theme.set_stylebox("grabber_area", "HSlider", slider_grabber_area)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_grabber_area)

	# --- RichTextLabel ---
	var rtl_bg := StyleBoxFlat.new()
	rtl_bg.bg_color = Color(0, 0, 0, 0)
	theme.set_stylebox("normal", "RichTextLabel", rtl_bg)
	theme.set_color("default_color", "RichTextLabel", COLOR_TEXT)

	# --- PopupMenu (for OptionButton dropdowns) ---
	var popup_bg := StyleBoxFlat.new()
	popup_bg.bg_color = COLOR_BG
	popup_bg.border_color = COLOR_BORDER
	popup_bg.set_border_width_all(BORDER_WIDTH)
	popup_bg.set_corner_radius_all(CORNER_RADIUS)
	popup_bg.shadow_color = Color(0, 0, 0, 0.5)
	popup_bg.shadow_size = 6
	theme.set_stylebox("panel", "PopupMenu", popup_bg)
	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = COLOR_SELECTION
	popup_hover.set_corner_radius_all(2)
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	theme.set_color("font_color", "PopupMenu", COLOR_TEXT)
	theme.set_color("font_hover_color", "PopupMenu", COLOR_TEXT_BRIGHT)

	# --- TooltipPanel ---
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.08, 0.10, 0.15, 0.95)
	tooltip_style.border_color = COLOR_ACCENT_DIM
	tooltip_style.set_border_width_all(1)
	tooltip_style.set_corner_radius_all(4)
	tooltip_style.set_content_margin_all(6)
	theme.set_stylebox("panel", "TooltipPanel", tooltip_style)
	theme.set_color("font_color", "TooltipLabel", COLOR_TEXT_BRIGHT)

	return theme


static func _make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_content_margin_all(CONTENT_MARGIN)
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style
