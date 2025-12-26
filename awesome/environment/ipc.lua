local awful = require("awful")
local json = require("util.json")
local socket = require("socket.unix")

local ipc = {}

local SOCKET_PATH = "/tmp/awesome-ipc.sock"
os.remove(SOCKET_PATH)

local server = socket()
server:bind(SOCKET_PATH)
server:listen(5)

server:settimeout(0)

local clients = {}

local function get_clients()
  local l = {}
  for _, c in ipairs(client.get()) do
    table.insert(l, {
      id = tostring(c.window),
      name = c.name or "",
      class = c.class or "",
      pid = c.pid or 0,
      focused = c == client.focus,
      last_focused = c.last_focused or 0,
      urgent = c.urgent,
      fullscreen = c.fullscreen,
      geometry = c:geometry(),
    })
  end
  return l
end

local function get_workspaces()
  local l = {}
  for s in screen do
    for _, t in ipairs(s.tags) do
      local tag_clients = {}
      for _, c in ipairs(t:clients()) do
        table.insert(tag_clients, tostring(c.window))
      end

      table.insert(l, {
        name = t.name,
        index = t.index,
        screen = s.index,
        selected = t.selected,
        urgent = #t:clients() > 0 and awful.tag.getproperty(t, "urgent") or false,
        clients = tag_clients
      })
    end
  end
  return l
end

local function get_screens()
  local l = {}
  for s in screen do
    table.insert(l, {
      index = s.index,
      focused = mouse.screen.index == s.index
    })
  end
  return l
end

local function broadcast_update(data)
  local message = json.encode(data) .. "\n"
  for i = #clients, 1, -1 do
    local client_sock = clients[i]
    local success, _ = client_sock:send(message)
    if not success then
      client_sock:close()
      table.remove(clients, i)
    end
  end
end

local function send_full_update()
  local data = {
    type = "full",
    timestamp = os.time(),
    clients = get_clients(),
    workspaces = get_workspaces(),
    screens = get_screens(),
  }
  broadcast_update(data)
end

local function process_ipc()
  local csock = server:accept()
  if csock then
    csock:settimeout(0)
    table.insert(clients, csock)
    send_full_update()
  end

  for i = #clients, 1, -1 do
    local csock1 = clients[i]
    local data, err = csock1:receive("*l")

    if data then
      -- do nothing
    elseif err == "closed" then
      csock1:close()
      table.remove(clients, i)
    end
  end
end

local timer = require("gears.timer")
ipc.timer = timer {
  timeout = 0.1,
  autostart = true,
  callback = process_ipc
}

client.connect_signal("manage", send_full_update)
client.connect_signal("unmanage", send_full_update)
client.connect_signal("focus", send_full_update)
client.connect_signal("unfocus", send_full_update)
client.connect_signal("property::name", send_full_update)
client.connect_signal("property::minimized", send_full_update)
client.connect_signal("property::fullscreen", send_full_update)
client.connect_signal("property::zoned", send_full_update)
screen.connect_signal("tag::history::update", send_full_update)

-- last focus date
client.connect_signal("focus", function(c)
  c.last_focused = os.time();
end)

awesome.connect_signal("exit", function()
  for _, csock in ipairs(clients) do
    csock:close()
  end
  server:close()
  os.remove(SOCKET_PATH)
end)

return ipc
