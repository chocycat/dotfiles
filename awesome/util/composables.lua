---@diagnostic disable: lowercase-global

local xresources = require("beautiful.xresources")
gears            = require("gears")
awful            = require("awful")
wibox            = require("wibox")
beautiful        = require("beautiful")
menubar          = require("menubar")
hotkeys_popup    = require("awful.hotkeys_popup")
dpi              = xresources.apply_dpi
lgi              = require("lgi")
cairo            = lgi.cairo
Pango            = lgi.Pango
PangoCairo       = lgi.PangoCairo

function Each_screen(f)
  awful.screen.connect_for_each_screen(f)
end
