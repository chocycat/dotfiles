---@diagnostic disable: lowercase-global

require("util.composables")

require("awful.autofocus")
require("awful.hotkeys_popup.keys")

require("keys")
require("rules")

local wallpaper = require("ui.wallpaper")
local window = require("ui.window")
local resize = require("ui.resize")
local titlebar = require("ui.titlebar")
spawner = require("util.spawner")

window.init()
resize.init()
spawner.init()
titlebar.init()

require("modules")

Each_screen(function(s)
  wallpaper.set(s)
  awful.tag({ "1" }, s, awful.layout.layouts[0])
end)

function _set_xproperty(pid, prop, value)
  awesome.register_xproperty(prop, "string")
  for _, c in ipairs(client.get()) do
    if c.pid == pid then
      c:set_xproperty(prop, value)
      client.emit_signal("xproperties::change", c)
      break
    end
  end
end
