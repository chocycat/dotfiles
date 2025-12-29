local resize = {}

local cfg = {
  handle_size = dpi(16),
  min_width = dpi(50),
  min_height = dpi(25),

  outline = {
    border = dpi(1.5),
    outer_width = dpi(3),
    inner_width = dpi(1),
    offset_x = dpi(1),
    extra_width = dpi(4),
    extra_height = dpi(3),
  },
}

local cors = { "top_left", "top_right", "bottom_left", "bottom_right" }

local curs = {
  top_left = "top_left_corner",
  top_right = "top_right_corner",
  bottom_left = "bottom_left_corner",
  bottom_right = "bottom_right_corner",
}

local handles = setmetatable({}, { __mode = "k" })
local outline = nil

local function make_outline()
  local widget = wibox.widget.base.make_widget()
  local o = cfg.outline

  function widget:fit(_, w, h)
    return w, h
  end

  function widget:draw(_, cr, w, h)
    cr:set_source_rgb(1, 1, 1)
    cr:set_line_width(o.outer_width)
    cr:rectangle(o.border, o.border, w - o.outer_width, h - o.outer_width)
    cr:stroke()

    cr:set_source_rgb(0, 0, 0)
    cr:set_line_width(o.inner_width)
    cr:rectangle(o.border, o.border, w - o.outer_width, h - o.outer_width)
    cr:stroke()
  end

  return widget
end

local function get_ol()
  if not outline then
    outline = wibox({
      ontop = true,
      visible = false,
      bg = "#00000000",
      type = "utility",
      widget = make_outline(),
    })
  end
  return outline
end

local function calc_geo(start, cor, dx, dy)
  local x, y = start.x, start.y
  local w, h = start.width, start.height

  if cor == "bottom_right" then
    w = start.width + dx
    h = start.height + dy
  elseif cor == "bottom_left" then
    w = start.width - dx
    x = start.x + dx
    h = start.height + dy
  elseif cor == "top_right" then
    w = start.width + dx
    h = start.height - dy
    y = start.y + dy
  elseif cor == "top_left" then
    w = start.width - dx
    h = start.height - dy
    x = start.x + dx
    y = start.y + dy
  end

  if w < cfg.min_width then
    if cor == "bottom_left" or cor == "top_left" then
      x = start.x + start.width - cfg.min_width
    end
    w = cfg.min_width
  end

  if h < cfg.min_height then
    if cor == "top_left" or cor == "top_right" then
      y = start.y + start.height - cfg.min_height
    end
    h = cfg.min_height
  end

  return { x = x, y = y, width = w, height = h }
end

local function to_ol(g)
  local o = cfg.outline
  return {
    x = g.x - o.offset_x,
    y = g.y,
    width = g.width + o.extra_width,
    height = g.height + o.extra_height,
  }
end

local function from_ol(g)
  local o = cfg.outline
  return {
    x = g.x + o.offset_x,
    y = g.y,
    width = g.width - o.extra_width,
    height = g.height - o.extra_height,
  }
end

local function drag(c, cor)
  local g = c:geometry()
  local m = mouse.coords()

  local sx, sy = m.x, m.y
  local start = { x = g.x, y = g.y, width = g.width, height = g.height }

  local ol = get_ol()
  ol:geometry(to_ol(start))
  ol.visible = true

  if handles[c] then
    for _, h in pairs(handles[c]) do
      h.visible = false
    end
  end

  mousegrabber.run(function(ms)
    if ms.buttons[1] then
      local dx = ms.x - sx
      local dy = ms.y - sy

      local ng = calc_geo(start, cor, dx, dy)
      ol:geometry(to_ol(ng))

      return true
    end

    local fg = from_ol(ol:geometry())
    c:geometry(fg)
    ol.visible = false

    if handles[c] then
      for _, h in pairs(handles[c]) do
        h.visible = true
      end
    end

    return false
  end, curs[cor])
end

local function handle_pos(g, cor)
  local half = cfg.handle_size / 2

  if cor == "top_left" then
    return { x = g.x - half, y = g.y - half }
  elseif cor == "top_right" then
    return { x = g.x + g.width - half, y = g.y - half }
  elseif cor == "bottom_left" then
    return { x = g.x - half, y = g.y + g.height - half }
  elseif cor == "bottom_right" then
    return { x = g.x + g.width - half, y = g.y + g.height - half }
  end
end

local function update_pos(c)
  local hs = handles[c]
  if not hs then return end

  local g = c:geometry()

  for cor, h in pairs(hs) do
    local p = handle_pos(g, cor)
    h:geometry({
      x = p.x,
      y = p.y,
      width = cfg.handle_size,
      height = cfg.handle_size,
    })
  end
end

local function make_handle(c, cor)
  local h = wibox({
    visible = true,
    bg = "#00000000",
    type = "utility",
    ontop = true,
    width = cfg.handle_size,
    height = cfg.handle_size,
  })

  h:connect_signal("mouse::enter", function()
    h.cursor = curs[cor]
  end)

  h:connect_signal("mouse::leave", function()
    h.cursor = "left_ptr"
  end)

  h:connect_signal("button::press", function(_, _, _, button)
    if button == 1 then
      c:emit_signal("request::activate", "resize", { raise = true })
      drag(c, cor)
    end
  end)

  return h
end

local function setup(c)
  if handles[c] then return end

  local hs = {}

  for _, cor in ipairs(cors) do
    hs[cor] = make_handle(c, cor)
  end

  handles[c] = hs
  update_pos(c)
end

local function remove(c)
  local hs = handles[c]
  if not hs then return end

  for _, h in pairs(hs) do
    h.visible = false
    h:disconnect_signal("mouse::enter", function() end)
    h:disconnect_signal("mouse::leave", function() end)
    h:disconnect_signal("button::press", function() end)
  end

  handles[c] = nil
end

function resize.init()
  client.connect_signal("manage", function(c)
    setup(c)

    c:connect_signal("property::geometry", function()
      update_pos(c)
    end)
  end)

  client.connect_signal("unmanage", function(c)
    remove(c)
  end)

  client.connect_signal("focus", function(c)
    if handles[c] then
      for _, h in pairs(handles[c]) do
        h.visible = true
      end
    end
  end)

  client.connect_signal("unfocus", function(c)
    if handles[c] then
      for _, h in pairs(handles[c]) do
        h.visible = false
      end
    end
  end)
end

resize.setup = setup
resize.remove = remove

return resize
