extends Button
class_name ActionButton

var action: CombatAction
var action_index: int

# Style constants
const NORMAL_COLOR := Color(0.2, 0.2, 0.3, 0.8)
const HOVER_COLOR := Color(0.3, 0.3, 0.4, 0.9)
const PRESSED_COLOR := Color(0.15, 0.15, 0.25, 1.0)
const BUTTON_SIZE := Vector2(64, 64)  # Make it square for circle

func _ready() -> void:
    setup_style()

func setup_style() -> void:
    # Force square size for circle
    size = BUTTON_SIZE
    custom_minimum_size = BUTTON_SIZE
    
    # Create circular StyleBoxFlat
    var normal_style = StyleBoxFlat.new()
    normal_style.bg_color = NORMAL_COLOR
    normal_style.border_width_all = 2  # Use all borders at once
    normal_style.border_color = Color.WHITE
    normal_style.corner_radius_all = int(BUTTON_SIZE.x / 2)  # Make perfectly round
    normal_style.corner_detail = 32  # Increase smoothness of circle
    
    var hover_style = normal_style.duplicate()
    hover_style.bg_color = HOVER_COLOR
    hover_style.border_color = Color(1, 1, 1, 1)
    
    var pressed_style = normal_style.duplicate()
    pressed_style.bg_color = PRESSED_COLOR
    
    # Apply styles
    add_theme_stylebox_override("normal", normal_style)
    add_theme_stylebox_override("hover", hover_style)
    add_theme_stylebox_override("pressed", pressed_style)
    
    # Center everything
    text = ""
    expand_icon = true
    icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
    
    # Ensure the button doesn't resize
    focus_mode = Control.FOCUS_NONE
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(combat_action: CombatAction, index: int) -> void:
    action = combat_action
    action_index = index
    tooltip_text = action.description
    
    # Set up icon
    if action.icon:
        icon = action.icon
        # Make icon fill most of the circle but not all
        add_theme_constant_override("icon_max_width", int(BUTTON_SIZE.x * 0.6))
        add_theme_constant_override("icon_max_height", int(BUTTON_SIZE.y * 0.6))
    else:
        # Fallback text if no icon
        text = action.action_name.substr(0, 1)  # First letter
        add_theme_font_size_override("font_size", 24)
        add_theme_color_override("font_color", Color.WHITE)