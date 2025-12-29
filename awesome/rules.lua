local client_buttons = gears.table.join(
  awful.button({}, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
  end)
)

local cfg = {
  cascade_offset_x = dpi(10),
  cascade_offset_y = dpi(10),
  padding = dpi(10),
}
local cascade_index = 0

local function cascade_placement(c)
  if c.type == "utility" or c.type == "desktop" then return end;

  local workarea = c.screen.workarea
  local geo = c:geometry()

  local max_cascade_x = math.floor((workarea.width - geo.width - cfg.padding) / cfg.cascade_offset_x)
  local max_cascade_y = math.floor((workarea.height - geo.height - cfg.padding) / cfg.cascade_offset_y)
  local max_cascade = math.max(1, math.min(max_cascade_x, max_cascade_y))

  cascade_index = cascade_index % max_cascade

  local x = workarea.x + cfg.padding + (cascade_index * cfg.cascade_offset_x)
  local y = workarea.y + cfg.padding + (cascade_index * cfg.cascade_offset_y)

  c:geometry({ x = x, y = y })

  cascade_index = cascade_index + 1
end

awful.rules.rules = {
  {
    rule = {},
    properties = {
      focus = awful.client.focus.filter,
      raise = true,
      screen = awful.screen.preferred,
      placement = cascade_placement
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
      type = "desktop"
    }
  },

  client.connect_signal("manage", function(c)
    if c.name == "system::desktop" then
      c.below = true
      c.x = 0
      c.y = 0
      c.immobilized = true
    end
  end),

  client.connect_signal("property::maximized", function(c)
    if not c.maximized then
      c.border_width = 1
    end
  end)
}

screen.connect_signal("tag::history::update", function(s)
  local dominated = #s.clients > 0
  if not dominated then
    cascade_index = 0
  end
end)
