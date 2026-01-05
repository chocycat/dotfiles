local spawner = {
  windows = {}
}

local motion = require("util.motion")

awesome.register_xproperty("_SPAWN_OUTLINE", "string")
awesome.register_xproperty("_OUTLINE_MIN_ACTIVE", "string")

function spawner.init()
  client.connect_signal("unmanage", function(c)
    local dims = spawner.windows[c.window]
    if not dims then return end

    local geo = c:geometry()
    local outline = motion.create_outline(geo.x, geo.y, geo.width, geo.height, "_OUTLINE_MIN_ACTIVE")
    motion.show(outline)
    outline.drawin:set_xproperty("_SPAWN_OUTLINE", "true")

    gears.timer.start_new(0.05, function()
      motion.animate_to_geometry(outline, { x = dims.x, y = dims.y, width = dims.w, height = dims.h }, function() end)
    end)
  end)
end

function spawner.spawn_from(cmd, x, y, w, h)
  -- we are most likely spawning from the desktop
  -- so we need to add +18 points, as there's top padding
  local outline = motion.create_outline(x, y, w, h)
  outline.drawin:set_xproperty("_SPAWN_OUTLINE", "true")

  local handled = false

  local function handle_client(c)
    if c.handled then return end

    spawner.windows[c.window] = { x = x, y = y, w = w, h = h }

    c.handled = true
    c.hidden = true
    handled = true

    motion.animate_to_client(outline, c, function()
      c.hidden = false
      c:raise()
      client.focus = c
    end)
  end

  local pid = -1

  local function on_manage(c)
    if c.pid ~= pid then return end
    handle_client(c)
  end

  pid = awful.spawn.with_shell(cmd, {
    callback = handle_client,
  })

  client.connect_signal("manage", on_manage)

  gears.timer.start_new(10, function()
    if not handled then
      motion.hide(outline)
    end
    client.disconnect_signal("manage", on_manage)
    return false
  end)
end

return spawner
