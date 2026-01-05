local client_buttons = gears.table.join(
  awful.button({}, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
  end)
)

local placement = require("ui.placement")

awesome.register_xproperty("_FM_PATH", "string")

awful.rules.rules = {
  {
    rule = {},
    properties = {
      focus = awful.client.focus.filter,
      raise = true,
      screen = awful.screen.preferred,
      placement = placement.placement,
    }
  },
  {
    rule_any = { class = "apps" },
    properties = {
      size_hints_honor = false,
      placement = placement.placement,
    }
  },
  {
    rule_any = { type = { "normal", "dialog" } },
    properties = {
      titlebars_enabled = true,
      buttons = client_buttons
    }
  },
  {
    rule_any = { type = { "dialog", "splash" } },
    properties = {
      floating = true,
      placement = awful.placement.centered,
    }
  },
  {
    rule_any = { name = "system::desktop" },
    properties = {
      titlebars_enabled = false,
      border_width = 0,
      sticky = true,
      floating = true,
    }
  },

  client.connect_signal("manage", function(c)
    if c.name == "system::desktop" then
      c.floating = true
      c.below = true
      c.x = 0
      c.y = dpi(-18)
      c.immobilized = true
      c.type = "desktop"
      c.size_hints_honor = true
      return
    end
  end),

  client.connect_signal("request::geometry", function(c, context, hints)
    if c.name ~= "system::desktop" and context == "ewmh" then
      placement.placement(c)
    end
  end)
}

tag.connect_signal("property::selected", function(t)
  placement.reset_cascade(t.screen)
end)
