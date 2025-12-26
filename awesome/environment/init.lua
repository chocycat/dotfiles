local master = require("layout")

SUPER_KEY = "Mod4"

SOFTWARE = {
  TERMINAL = "wezterm",
  EDITOR = "nvim",
  SCREENSHOT = "flameshot gui"
}

LAYOUTS = {
  master.layout,
  awful.layout.suit.floating,
}

awful.layout.layouts = LAYOUTS

require("environment.keybinds")
require("environment.rules")
require("environment.ipc")
require("environment.autostart")
