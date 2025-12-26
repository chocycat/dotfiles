local wezterm = require('wezterm')
local config = wezterm.config_builder()

config.audible_bell = "Disabled"

config.initial_cols = 120
config.initial_rows = 28

config.max_fps = 120

config.front_end = 'WebGpu'
config.webgpu_power_preference = "HighPerformance"

config.tiling_desktop_environments = {
  'X11 awesome'
}

config.font = wezterm.font('Fairfax')
config.font_size = 13

config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.8
}

config.colors = {
  foreground = '#cac4d4',
  background = '#141118',

  cursor_bg = '#a980db',
  cursor_border = '#a980db',
  cursor_fg = '#141118',

  selection_bg = '#27222f',

  split = "#27222f",

  ansi = {
    "#4f455f",
    "#d66f6f",
    "#6fd692",
    "#d6d36f",
    "#6f9ad6",
    "#9e70d7",
    "#6fd6d6",
    "#f4f3f6"
  },

  brights = {
    "#4f455f",
    "#d66f6f",
    "#6fd692",
    "#d6d36f",
    "#6f9ad6",
    "#9e70d7",
    "#6fd6d6",
    "#f4f3f6"
  },

  tab_bar = {
    background = '#141118',

    active_tab = {
      bg_color = '#1e1a24',
      fg_color = '#cac4d4',
    },

    inactive_tab = {
      bg_color = '#141118',
      fg_color = '#a095b2',
    },

    inactive_tab_hover = {
      bg_color = '#1e1a24',
      fg_color = '#a095b2',
    },

    new_tab = {
      bg_color = '#141118',
      fg_color = '#a095b2',
    },

    new_tab_hover = {
      bg_color = '#1e1a24',
      fg_color = '#cac4d4',
    }
  }
}

config.enable_tab_bar = false
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.enable_wayland = false

config.window_close_confirmation = 'NeverPrompt'

config.window_padding = {
  left = 32,
  right = 32,
  top = 24,
  bottom = 24,
}

config.window_frame = {
  font = wezterm.font('Fairfax'),
}

config.disable_default_key_bindings = true

local act = wezterm.action
config.keys = {
  { key = '=',          mods = 'CTRL',           action = act.IncreaseFontSize },
  { key = '=',          mods = 'SHIFT|CTRL',     action = act.IncreaseFontSize },

  { key = 'C',          mods = 'CTRL',           action = act.CopyTo 'Clipboard' },
  { key = 'C',          mods = 'SHIFT|CTRL',     action = act.CopyTo 'Clipboard' },
  { key = 'c',          mods = 'SHIFT|CTRL',     action = act.CopyTo 'Clipboard' },
  { key = 'V',          mods = 'CTRL',           action = act.PasteFrom 'Clipboard' },
  { key = 'V',          mods = 'SHIFT|CTRL',     action = act.PasteFrom 'Clipboard' },
  { key = 'v',          mods = 'SHIFT|CTRL',     action = act.PasteFrom 'Clipboard' },

  { key = 'T',          mods = 'CTRL',           action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'T',          mods = 'SHIFT|CTRL',     action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 't',          mods = 'SHIFT|CTRL',     action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'W',          mods = 'CTRL',           action = act.CloseCurrentTab { confirm = true } },
  { key = 'W',          mods = 'SHIFT|CTRL',     action = act.CloseCurrentTab { confirm = true } },
  { key = 'w',          mods = 'SHIFT|CTRL',     action = act.CloseCurrentTab { confirm = true } },

  { key = 'LeftArrow',  mods = 'SHIFT|CTRL',     action = act.ActivatePaneDirection 'Left' },
  { key = 'LeftArrow',  mods = 'SHIFT|ALT|CTRL', action = act.AdjustPaneSize { 'Left', 1 } },
  { key = 'RightArrow', mods = 'SHIFT|CTRL',     action = act.ActivatePaneDirection 'Right' },
  { key = 'RightArrow', mods = 'SHIFT|ALT|CTRL', action = act.AdjustPaneSize { 'Right', 1 } },
  { key = 'UpArrow',    mods = 'SHIFT|CTRL',     action = act.ActivatePaneDirection 'Up' },
  { key = 'UpArrow',    mods = 'SHIFT|ALT|CTRL', action = act.AdjustPaneSize { 'Up', 1 } },
  { key = 'DownArrow',  mods = 'SHIFT|CTRL',     action = act.ActivatePaneDirection 'Down' },
  { key = 'DownArrow',  mods = 'SHIFT|ALT|CTRL', action = act.AdjustPaneSize { 'Down', 1 } },

  { key = '\"',         mods = 'ALT|CTRL',       action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = '\"',         mods = 'SHIFT|ALT|CTRL', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = '%',          mods = 'ALT|CTRL',       action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '%',          mods = 'SHIFT|ALT|CTRL', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '\'',         mods = 'SHIFT|ALT|CTRL', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = '5',          mods = 'SHIFT|ALT|CTRL', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
}


return config
