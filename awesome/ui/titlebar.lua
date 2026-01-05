local titlebar = {}

local pat = require("util.pattern")

local cfg = {
  height = dpi(17) + dpi(1),
  padding = dpi(3),
  gap = dpi(1),
  title_padding = dpi(8),
  button_size = dpi(11),
  stripe_thickness = dpi(1),
  stripe_gap = dpi(1),
  font = "Chicago Kare " .. tostring(math.floor(dpi(12))),
  button_margin = dpi(8),
  button_spacing = dpi(14),
  title_y_offset = 1,
  outline = {
    border = dpi(1.5),
    outer_width = dpi(3),
    inner_width = dpi(1),
    offset_x = dpi(1),
    extra_width = dpi(4),
    extra_height = dpi(3),
  },
  drag_bounds = dpi(4),
}

local fopts = cairo.FontOptions.create()
fopts:set_antialias(cairo.Antialias.NONE)
fopts:set_hint_style(cairo.HintStyle.FULL)
fopts:set_hint_metrics(cairo.HintMetrics.ON)
fopts:set_subpixel_order(cairo.SubpixelOrder.DEFAULT)

local outline = nil

local function make_btn(opts, idle, active, on_click)
  return {
    index = opts.index or 1,
    align = opts.align or "left",
    idle_pattern = idle,
    active_pattern = active,
    on_click = on_click,
    pressed = false,
  }
end

local function btn_x(b, w)
  local offset = cfg.button_margin + (b.index - 1) * cfg.button_spacing
  if b.align == "right" then
    return w - offset - cfg.button_size
  end
  return offset
end

local function hit_test(b, x, y, w)
  local bx = btn_x(b, w)
  return x >= bx and x <= bx + cfg.button_size
      and y >= cfg.padding and y <= cfg.padding + cfg.button_size
end

local function draw_underlay(cr, b, w)
  local bx = btn_x(b, w)
  cr:set_source_rgb(1, 1, 1)
  cr:rectangle(bx - cfg.gap, cfg.padding, cfg.button_size + cfg.gap * 2, cfg.button_size)
  cr:fill()
end

local function draw_pat(cr, b, w, p)
  local bx = btn_x(b, w)
  local sz = #p
  local scale = math.floor(cfg.button_size / sz)
  local total = sz * scale
  local offset = math.floor((cfg.button_size - total) / 2)
  pat.draw_opaque(cr, p, bx + offset, cfg.padding + offset, scale)
end

local function draw_btn(cr, b, w)
  local bx = btn_x(b, w)
  local half = cfg.stripe_thickness / 2
  local inset = cfg.button_size - cfg.stripe_thickness

  cr:set_source_rgb(0, 0, 0)
  cr:set_line_width(cfg.stripe_thickness)
  cr:rectangle(bx + half, cfg.padding + half, inset, inset)
  cr:stroke()

  if b.pressed and b.active_pattern then
    draw_pat(cr, b, w, b.active_pattern)
  elseif b.idle_pattern then
    draw_pat(cr, b, w, b.idle_pattern)
  end
end

local function make_outline()
  local widget = wibox.widget.base.make_widget()
  local o = cfg.outline

  function widget:fit(_, w, h)
    return w, h
  end

  function widget:draw(_, cr, w, h)
    local rw = w - o.outer_width
    local rh = h - o.outer_width

    cr:set_source_rgb(1, 1, 1)
    cr:set_line_width(o.outer_width)
    cr:rectangle(o.border, o.border, rw, rh)
    cr:stroke()

    cr:set_source_rgb(0, 0, 0)
    cr:set_line_width(o.inner_width)
    cr:rectangle(o.border, o.border, rw, rh)
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

local function is_titlebar_visible(y)
  local titlebar_bottom = y + cfg.height

  for s in screen do
    local wa = s.workarea

    if y >= wa.y
        and titlebar_bottom <= wa.y + wa.height then
      return true
    end
  end

  return false
end

local function drag(c)
  local m = mouse.coords()
  local o = cfg.outline

  local g = c:geometry()
  local ox = m.x - g.x
  local oy = m.y - g.y

  local last_valid_x = g.x
  local last_valid_y = g.y
  local is_valid = true

  local ol = get_ol()
  ol:geometry({
    x = g.x - o.offset_x,
    y = g.y,
    width = g.width + o.extra_width,
    height = g.height + o.extra_height,
  })
  ol.visible = true

  mousegrabber.run(function(ms)
    if ms.buttons[1] then
      local new_x = ms.x - ox
      local new_y = ms.y - oy

      if is_titlebar_visible(new_y) then
        ol:geometry({
          x = new_x - o.offset_x,
          y = new_y,
        })
        ol.visible = true
        last_valid_x = new_x
        last_valid_y = new_y
        is_valid = true
      else
        ol.visible = false
        is_valid = false
      end
      return true
    end

    ol.visible = false

    if is_valid then
      c:geometry({
        x = last_valid_x,
        y = last_valid_y,
      })
    end

    return false
  end, "left_ptr")
end

local function stripes(cr, w, h)
  cr:set_source_rgb(0, 0, 0)
  local step = cfg.stripe_thickness + cfg.stripe_gap
  for y = cfg.padding, h - cfg.padding - cfg.stripe_thickness, step do
    cr:rectangle(cfg.gap, y, w - cfg.gap * 2, cfg.stripe_thickness)
  end
  cr:fill()
end

local function border(cr, w)
  cr:set_source_rgb(0, 0, 0)
  cr:rectangle(0, cfg.height - cfg.stripe_thickness, w, cfg.stripe_thickness)
  cr:fill()
end

local function title(cr, name, w, h)
  local txt = name == "st" and "Terminal" or (name or "")

  local p = PangoCairo.create_context(cr)
  PangoCairo.context_set_font_options(p, fopts)

  local l = Pango.Layout.new(p)
  l:set_font_description(Pango.FontDescription.from_string(cfg.font))
  l:set_text(txt, -1)

  local tw = l:get_pixel_size()
  local tx = math.floor((w - tw) / 2)

  cr:set_source_rgb(1, 1, 1)
  cr:rectangle(tx - cfg.title_padding, 0, tw + cfg.title_padding * 2, h - cfg.stripe_thickness)
  cr:fill()

  cr:set_source_rgb(0, 0, 0)
  cr:move_to(tx, cfg.title_y_offset)
  PangoCairo.show_layout(cr, l)
end

local function make_widget(c, btns)
  local widget = wibox.widget.base.make_widget()

  function widget:fit(_, w, h)
    return w, h
  end

  function widget:draw(_, cr, w, h)
    cr:set_font_options(fopts)
    cr:set_source_rgb(1, 1, 1)
    cr:paint()

    if client.focus == c then
      stripes(cr, w, h)
      for _, b in ipairs(btns) do
        draw_underlay(cr, b, w)
      end
      for _, b in ipairs(btns) do
        draw_btn(cr, b, w)
      end
    end

    title(cr, c.name, w, h)
    border(cr, w)
  end

  return widget
end

local function find_btn(btns, x, y, w)
  for _, b in ipairs(btns) do
    if hit_test(b, x, y, w) then
      return b
    end
  end
  return nil
end

local function signals(tb, c, widget, btns)
  tb:connect_signal("button::press", function(_, _, _, button)
    if button ~= 1 then return end

    local m = mouse.coords()
    local g = c:geometry()
    local pressed = find_btn(btns, m.x - g.x, m.y - g.y, g.width)

    for _, b in ipairs(btns) do
      local was = b.pressed
      b.pressed = (b == pressed)
      if was ~= b.pressed then
        widget:emit_signal("widget::redraw_needed")
      end
    end

    if not pressed then
      c:emit_signal("request::activate", "titlebar", { raise = true })
      drag(c)
    end
  end)

  tb:connect_signal("button::release", function(_, _, _, button)
    if button == 1 then
      for _, b in ipairs(btns) do
        if b.pressed then
          b.on_click(c)
          b.pressed = false
          break
        end
      end
    elseif button == 2 then
      c:kill()
    end
  end)

  tb:connect_signal("mouse::leave", function()
    for _, b in ipairs(btns) do
      if b.pressed then
        b.pressed = false
        widget:emit_signal("widget::redraw_needed")
      end
    end
  end)

  c:connect_signal("property::name", function()
    widget:emit_signal("widget::redraw_needed")
  end)
end

function titlebar.init()
  client.connect_signal("request::titlebars", function(c)
    titlebar.setup(c)
  end)
end

function titlebar.setup(c)
  local btns = {
    make_btn({ align = "left" }, nil, pat.titlebar.pressed, function() c:kill() end),
    make_btn({ align = "right" }, pat.titlebar.maximize_idle, pat.titlebar.pressed,
      function() c.maximized = not c.maximized end)
  }

  local widget = make_widget(c, btns)

  local tb = awful.titlebar(c, {
    size = cfg.height,
    position = "top",
    bg = "#ffffff",
  })

  tb:setup({
    widget,
    layout = wibox.layout.stack,
  })

  signals(tb, c, widget, btns)
end

return titlebar
