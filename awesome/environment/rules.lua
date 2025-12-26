local master = require('layout')

local client_keys = gears.table.join(
  awful.key({ SUPER_KEY, }, "f",
    function(c)
      c.fullscreen = not c.fullscreen
      c:raise()
    end,
    { description = "toggle fullscreen", group = "client" }),
  awful.key({ SUPER_KEY, }, "m",
    function(c)
      if c.zoned == nil then c.zoned = false end
      c.zoned = not c.zoned
    end,
    { description = "(un)zone", group = "client" }),
  awful.key({ SUPER_KEY }, "c", function(c)
      if c.name == "polestar::desktop" then return end;
      c:kill()
    end,
    { description = "close", group = "client" }),
  awful.key({ SUPER_KEY, }, "o", function(c) c:move_to_screen() end,
    { description = "move to screen", group = "client" }),
  awful.key({ SUPER_KEY }, "g", function() client.focus.floating = not client.focus.floating end),
  awful.key({ SUPER_KEY }, "s", function() master.rotate(client.focus) end),
  awful.key({ SUPER_KEY, "Control" }, "Left", function() master.resize(client.focus, "left", 0.02) end),
  awful.key({ SUPER_KEY, "Control" }, "Right", function() master.resize(client.focus, "right", 0.02) end),
  awful.key({ SUPER_KEY, "Control" }, "Up", function() master.resize(client.focus, "up", 0.02) end),
  awful.key({ SUPER_KEY, "Control" }, "Down", function() master.resize(client.focus, "down", 0.02) end),
  awful.key({ SUPER_KEY, "Shift" }, "Left", function() master.swap_bydirection("left") end),
  awful.key({ SUPER_KEY, "Shift" }, "Right", function() master.swap_bydirection("right") end),
  awful.key({ SUPER_KEY, "Shift" }, "Up", function() master.swap_bydirection("up") end),
  awful.key({ SUPER_KEY, "Shift" }, "Down", function() master.swap_bydirection("down") end),
  awful.key({ SUPER_KEY }, "Left", function() awful.client.focus.bydirection("left") end),
  awful.key({ SUPER_KEY }, "Right", function() awful.client.focus.bydirection("right") end),
  awful.key({ SUPER_KEY }, "Up", function() awful.client.focus.bydirection("up") end),
  awful.key({ SUPER_KEY }, "Down", function() awful.client.focus.bydirection("down") end)
)

local client_buttons = gears.table.join(
  awful.button({}, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
  end),
  awful.button({ SUPER_KEY }, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })

    if c.type ~= "desktop" then
      if awful.layout.get(c.screen).name == 'master' and not c.floating then
        master.start_drag(c)
      else
        awful.mouse.client.move(c)
      end
    end
  end),
  awful.button({ SUPER_KEY }, 3, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
    awful.mouse.client.resize(c)
  end)
)

awful.rules.rules = {
  {
    rule = {},
    properties = {
      border_width = beautiful.border_width,
      border_color = beautiful.border_normal,
      focus = awful.client.focus.filter,
      raise = true,
      keys = client_keys,
      buttons = client_buttons,
      screen = awful.screen.preferred,
      placement = awful.placement.no_overlap + awful.placement.no_offscreen
    }
  },

  {
    rule_any = {
      instance = {},
      class = {},
      name = {
        "Event Tester",
      },
      role = {
        "pop-up",
      }
    },
    properties = { floating = true }
  },

  {
    rule_any = { class = { "tf_linux64" } },
    properties = { floating = true, titlebars_enabled = false, border_width = 0 }
  },

  {
    rule_any = { type = { "normal", "dialog" }
    },
    properties = { titlebars_enabled = true }
  },


  {
    rule_any = { name = { "polestar::bar" } },
    properties = {
      titlebars_enabled = false,
      border_width = 0,
      y = 0,
      sticky = true,
      ontop = true,
      type = "dock",
      focusable = false,
    },
  },

  {
    rule_any = { name = { "polestar::search" } },
    properties = {
      titlebars_enabled = false,
      border_width = 0,
      sticky = true,
      ontop = true,
      floating = true,
    }
  },

  {
    rule_any = { name = { "polestar::desktop" } },
    properties = {
      titlebars_enabled = false,
      border_width = 0,
      sticky = true,
      below = true,
      floating = true,
      screen = 1,
      focusable = false,
    },
  },

  {
    rule = { class = "Helium" },
    properties = { tag = "2-2", screen = 2 }
  },

  {
    rule_any = { class = { "Signal", "discord" } },
    properties = { tag = "2-3", screen = 2 },
  },

  client.connect_signal("manage", function(c)
    if awesome.startup
        and not c.size_hints.user_position
        and not c.size_hints.program_position then
      awful.placement.no_offscreen(c)
    end

    if c.name == "polestar::bar" then
      c.y = 0
    end

    if c.name == "polestar::search" then
      c.screen = mouse.screen
      awful.placement.centered(c, { honor_workarea = true })
    end

    if c.name == "polestar::desktop" then
      c.x = 0
      c.y = 0
      c.below = true
    end
  end),

  client.connect_signal("property::floating", function(c)
    if c.floating then
      c.above = true
    else
      c.above = false
    end
  end),

  client.connect_signal("property::fullscreen", function(c)
    if c.fullscreen then
      local geo = c.screen.geometry
      c:geometry({ x = geo.x, y = geo.y, width = geo.width, height = geo.height })
      c:raise()
    end
  end),

  client.connect_signal("property::zoned", function(c)
    if c.zoned then
      c.above = true

      local tag = c.first_tag
      if tag then
        for _, other in ipairs(tag:clients()) do
          if other ~= c and other.zoned then
            other.zoned = false
          end
        end
      end
    else
      c.above = false
    end

    c:raise()

    awful.layout.arrange(c.screen)
  end),

  client.connect_signal("focus", function(c)
    if c.__dragging or c.floating then return end

    local tag = c.first_tag
    if tag then
      for _, other in ipairs(tag:clients()) do
        if other ~= c and other.zoned then
          other.zoned = false
        end
      end
    end
  end)
}
