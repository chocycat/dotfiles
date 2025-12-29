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
local topbar = require("ui.topbar")

window.init()
resize.init()
titlebar.init()

local function arrange_once(layout)
  local s = awful.screen.focused()
  local t = s.selected_tag

  t.layout = layout
  awful.layout.arrange(s)

  t.layout = awful.layout.suit.floating
end

local function hide_desktop()
  for _, c in ipairs(client.get()) do
    if c:invisible() and not c.minimized then
      c.minimized = true
    end
  end
end

local function show_all_windows()
  for _, c in ipairs(client.get()) do
    if c.minimized then c.minimized = false end
  end
end

local default_menus = {
  {
    title = "∞",
    items = {
      { text = "About This Computer...", on_click = function() awful.spawn("st -e sh -c 'fastfetch; exec bash'") end },
      { separator = true },
      {
        text = "Applications",
        submenu = {

          { text = "Web Browser", on_click = function() awful.spawn("firefox") end },
          { text = "Code Editor", on_click = function() awful.spawn("st -e vim") end },
        }
      },
      { separator = true },
      { text = "Restart Interface", on_click = function() awesome.restart() end },
      { text = "Quit Interface",    on_click = function() awesome.quit() end },
      { separator = true },
      { text = "Power off",         on_click = function() awful.spawn("systemctl poweroff") end }
    }
  },
  {
    title = "File",
    items = {
      { text = "New Finder",      on_click = function() awful.spawn("pcmanfm") end },
      { text = "New Terminal",    on_click = function() awful.spawn("st") end },
      { separator = true },
      { text = "Open...",         on_click = function() awful.spawn("rofi -show drun") end },
      { separator = true },
      { text = "Print Screen",    on_click = function() awful.spawn("flameshot screen") end },
      { text = "Print Selection", on_click = function() awful.spawn("flameshot gui") end },
    }
  },
  {
    title = "View",
    items = {
      { text = "Clean Up",         on_click = function() arrange_once(awful.layout.suit.fair) end },
      { separator = true },
      { text = "Hide Desktop",     on_click = function() hide_desktop() end },
      { text = "Show All Windows", on_click = function() show_all_windows() end },
      { separator = true },
    }
  },
}

topbar.init({ screen = screen.primary })
topbar.set_menus(default_menus)

Each_screen(function(s)
  wallpaper.set(s)
  awful.tag({ "1" }, s, awful.layout.layouts[0])
end)

local appmenu = require("appmenu")

appmenu:connect_signal("menu::update", function(_, wid)
  for _, c in ipairs(client.get()) do
    if c.window == math.floor(wid) then
      appmenu.create_bar(c.window, function(app_menus)
        if app_menus and #app_menus > 0 then
          local menus = { default_menus[1] }
          for _, m in ipairs(app_menus) do
            table.insert(menus, m)
          end
          topbar.set_menus(menus)
        else
          topbar.set_menus(default_menus)
        end
      end)
    end
  end
end)

client.connect_signal("focus", function(c)
  if not c.window then
    topbar.set_menus(default_menus)
    return
  end

  appmenu.create_bar(c.window, function(app_menus)
    if app_menus and #app_menus > 0 then
      local menus = { default_menus[1] }
      for _, m in ipairs(app_menus) do
        table.insert(menus, m)
      end
      topbar.set_menus(menus)
    else
      topbar.set_menus(default_menus)
    end
  end)
end)


client.connect_signal("unfocus", function()
  topbar.set_menus(default_menus)
end)
