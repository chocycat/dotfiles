local spawner = {}

local motion = require("util.motion")

awesome.register_xproperty("_SPAWN_OUTLINE", "string")

function spawner.spawn_from(cmd, x, y, w, h)
  -- we are most likely spawning from the desktop
  -- so we need to add +18 points, as there's top padding
  local outline = motion.create_outline(x, y + dpi(18), w, h)
  outline.drawin:set_xproperty("_SPAWN_OUTLINE", "true")

  local handled = false

  local function handle_client(c)
    if c.handled then return end

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

  pid = awful.spawn(cmd, {
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
