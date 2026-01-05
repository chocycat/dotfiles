local lgi = require("lgi")
local GLib = lgi.GLib
local Gio = lgi.Gio
local json = require("util.json")

local M = {}

function M.create_watcher(path, callback)
  local socket_address = Gio.UnixSocketAddress.new(path)
  local client = Gio.SocketClient.new()

  local connection, err = client:connect(socket_address)
  if not connection then
    return nil, "failed to connect: " .. tostring(err)
  end

  local input_stream = connection:get_input_stream()
  local output_stream = connection:get_output_stream()
  local data_input = Gio.DataInputStream.new(input_stream)
  local _state = nil

  local watcher = {
    connection = connection,
    output_stream = output_stream,
    data_input = data_input,
    callback = callback,
    source_id = nil,
  }

  local function read_line_async()
    data_input:read_line_async(GLib.PRIORITY_DEFAULT, nil, function(obj, result)
      local line, _ = obj:read_line_finish(result)
      if line and #line > 0 then
        local ok, state = pcall(json.decode, line)
        if ok and state then
          _state = state
          callback(state)
        end
        read_line_async()
      else
        -- connection closed
        watcher:close()
      end
    end)
  end

  function watcher:set_callback(cb)
    callback = cb
  end

  function watcher:send(cmd)
    local bytes = cmd .. "\n"
    self.output_stream:write(bytes, nil)
    self.output_stream:flush(nil)
  end

  function watcher:cleanup()
    self:send("cleanup")
  end

  function watcher:new_folder()
    self:send("new_folder")
  end

  function watcher:select_all()
    self:send("select_all")
  end

  function watcher:open()
    self:send("open")
  end

  function watcher:close()
    if self.connection then
      self.connection:close()
      self.connection = nil
    end
  end

  function watcher:get_menus()
    local state = _state
    if state == nil then return nil end

    local cleanup_label = ""
    if state.any_selected then
      cleanup_label = " Selected"
    end

    return {
      {
        title = "File",
        items = {
          { text = "New Folder", on_click = function() watcher:send("new_folder") end },
          { text = "Open",       on_click = function() watcher:send("open") end,      enabled = state.any_selected },
          { text = "Rename",     on_click = function() watcher:send("rename") end,    enabled = state.any_selected },
          { separator = true },
          { text = "Delete",     on_click = function() watcher:send("delete") end,    enabled = state.any_selected },
          { separator = true },
          { text = "Quit Finder",     on_click = function() client.focus:kill() end,    enabled = state.any_selected },
        },
      },
      {
        title = "Edit",
        items = {
          { text = "Select All", on_click = function() watcher:send("select_all") end }
        }
      },
      {
        title = "View",
        items = {
          { text = "Clean Up" .. cleanup_label, on_click = function() watcher:send("cleanup") end },
        }
      }
    }
  end

  read_line_async()

  return watcher
end

return M
