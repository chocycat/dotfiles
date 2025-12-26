local gfs         = require("gears.filesystem")

local themes_path = gfs.get_themes_dir()

return {
  font              = "Fairfax, 13",
  font_bold         = "Fairfax, Bold 13",
  font_italic       = "Fairfax, Italic 13",
  font_bold_italic  = "Fairfax, Bold Italic 13",

  bg_normal         = colors.base00,
  bg_focus          = colors.base02,
  bg_urgent         = colors.base08,
  bg_minimize       = colors.base02,
  bg_systray        = colors.base00,

  fg_normal         = colors.base06,
  fg_focus          = colors.base07,
  fg_urgent         = colors.base07,
  fg_minimize       = colors.base07,

  useless_gap       = dpi(10),
  border_width      = dpi(1.5),
  border_normal     = colors.base01,
  border_focus      = colors.base0C,
  border_marked     = colors.base0C,

  menu_submenu_icon = themes_path .. "default/submenu.png",
  menu_height       = dpi(24),
  menu_width        = dpi(128),

  icon_theme        = nil,
}
