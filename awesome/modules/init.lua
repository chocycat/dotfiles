local appmenu = require("appmenu")
local topbar = require("ui.topbar")
local desktop = require("modules.desktop")
local fm = require("modules.fm")
local battery = require("modules.battery")

awesome.register_xproperty("_FM_PATH", "string")

local function arrange_once(layout)
  local s = awful.screen.focused()
  local t = s.selected_tag

  t.layout = layout
  awful.layout.arrange(s)

  t.layout = awful.layout.suit.floating
end

local function hide_desktop()
  for _, c in ipairs(client.get()) do
    if c.hidden and not c.minimized then
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
  root = {
    {
      title = "∞",
      items = {
        { text = "About This Computer...", on_click = function() awful.spawn("st -e sh -c 'fastfetch; exec bash'") end },
        { separator = true },
        { text = "Web Browser",            on_click = function() awful.spawn("firefox") end },
        { text = "Code Editor",            on_click = function() awful.spawn("st -e vim") end },
        { text = "Note Pad",               on_click = function() awful.spawn("notepad") end },
        { separator = true },
        { text = "Restart Interface",      on_click = function() awesome.restart() end },
        { text = "Quit Interface",         on_click = function() awesome.quit() end },
        { separator = true },
        { text = "Power off",              on_click = function() awful.spawn("systemctl poweroff") end }
      }
    },
    {
      title = "File",
      items = {
        { text = "New Finder",      on_click = function() awful.spawn("fileman") end },
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
      }
    },
  }
}

local watchers = {}

local function create_bar(c, recreate_socket)
  recreate_socket = recreate_socket or false

  -- we have predefined menus for system apps
  if c.name == "system::desktop" and watchers[c.name] then
    local desktop_menus = watchers[c.name]:get_menus()
    if not desktop_menus then return end

    local menus = { default_menus.root[1] }
    for _, m in ipairs(desktop_menus) do
      table.insert(menus, m)
    end
    topbar.set_menus(menus)

    return
  elseif c:get_xproperty("_FM_PATH") ~= "" then
    local path = c:get_xproperty("_FM_PATH")
    if recreate_socket or not watchers[path] then
      watchers[path] = fm.create_watcher(path, function()
        if client.focus.window == c.window then
          create_bar(client.focus)
        end
      end)
    end

    -- failed
    if not watchers[path] then return end

    local fm_menus = watchers[path]:get_menus()
    if not fm_menus then return end

    local menus = { default_menus.root[1] }
    for _, m in ipairs(fm_menus) do
      table.insert(menus, m)
    end

    topbar.set_menus(menus)

    return
  end

  appmenu.create_bar(c.window, function(app_menus)
    if app_menus and #app_menus > 0 then
      local menus = { default_menus.root[1] }
      for _, m in ipairs(app_menus) do
        table.insert(menus, m)
      end
      topbar.set_menus(menus)
    else
      topbar.set_menus(default_menus.root)
    end
  end)
end

watchers["system::desktop"] = desktop.create_watcher(function()
  if client.focus.name == "system::desktop" then
    create_bar(client.focus)
  end
end)

local battery_watcher = battery.create_watcher(function()
  topbar.redraw()
end)

local function build_tools()
  local tool_list = {}

  if battery_watcher:has_batteries() then
    table.insert(tool_list, battery_watcher:get_tool())
  end

  table.insert(tool_list, topbar.clock_tool())

  return tool_list
end

topbar.init({ screen = screen.primary })
topbar.set_menus(default_menus.root)
topbar.set_tools(build_tools())

appmenu:connect_signal("menu::update", function(_, wid)
  for _, c in ipairs(client.get()) do
    if c.window == math.floor(wid) then
      create_bar(c)
    end
  end
end)

client.connect_signal("focus", function(c)
  if not c.window then
    topbar.set_menus(default_menus.root)
    return
  end

  create_bar(c)
end)

client.connect_signal("unfocus", function(c)
  create_bar(c)
end)

-- emitted when an app uses _set_xproperty
-- this is an external call and is usually an 'init'
client.connect_signal("xproperties::change", function(c)
  create_bar(c, true)
end)
