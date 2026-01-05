local topbar = {}
local pattern = require("util.pattern")

local cfg = {
  height = dpi(20),
  padding_x = dpi(18),
  item_gap = dpi(15),
  menu_padding = dpi(10),
  font = "Chicago Kare " .. tostring(math.floor(dpi(12))),
  dropdown = {
    item_height = dpi(18),
    padding_x = dpi(16),
    min_width = dpi(140),
    separator_gap = dpi(9),
    dot_size = dpi(1),
    submenu_delay = 0.15,
    indicator_width = dpi(16),
    disabled_color = 0.5,
  }
}

local fopts = cairo.FontOptions.create()
fopts:set_antialias(cairo.Antialias.NONE)
fopts:set_hint_style(cairo.HintStyle.FULL)
fopts:set_hint_metrics(cairo.HintMetrics.ON)
fopts:set_subpixel_order(cairo.SubpixelOrder.DEFAULT)

local bar = nil
local menus = {}
local tools = {}
local extents = {}
local tool_extents = {}
local pool = {}
local stack = {}
local timer = nil
local active_tool = nil
local image_cache = {}

local function load_image(path, invert)
  if not path then return nil end

  local full_path = path
  if not path:match("^/") then
    full_path = gears.filesystem.get_configuration_dir() .. path
  end

  local key = full_path .. (invert and ":inv" or "")
  if image_cache[key] then
    return image_cache[key]
  end

  local ok, s = pcall(cairo.ImageSurface.create_from_png, full_path)
  if not ok or not s then
    return nil
  end

  if invert then
    local w = s:get_width()
    local h = s:get_height()
    local inv = cairo.ImageSurface.create(cairo.Format.ARGB32, w, h)
    local cr = cairo.Context.create(inv)

    cr:set_source_surface(s, 0, 0)
    cr:paint()
    cr:set_operator(cairo.Operator.DIFFERENCE)
    cr:set_source_rgb(1, 1, 1)
    cr:mask_surface(s, 0, 0)

    s = inv
  end

  image_cache[key] = s
  return s
end

local function measure(text)
  if not bar then return 0 end
  local s = cairo.ImageSurface.create(cairo.Format.ARGB32, 1, 1)
  local cr = cairo.Context.create(s)
  cr:set_font_options(fopts)
  local p = PangoCairo.create_context(cr)
  PangoCairo.context_set_font_options(p, fopts)
  local l = Pango.Layout.new(p)
  l:set_font_description(Pango.FontDescription.from_string(cfg.font))
  l:set_text(text, -1)
  local w = l:get_pixel_size()
  s:finish()
  return w
end

local function has_toggles(items)
  local has = false
  local max_width = 0

  for _, v in ipairs(items) do
    if v.checked ~= nil or v.radio ~= nil then
      has = true
    elseif v.images then
      has = true
      for _, img in ipairs(v.images) do
        if type(img) == "string" then
          local surface = load_image(img, false)
          if surface then
            max_width = math.max(max_width, surface:get_width())
          end
        elseif type(img) == "table" then
          if #img > 0 then
            max_width = math.max(max_width, #img[1] * dpi(1))
          end
        end
      end
    end
  end

  return has, max_width
end

local function dd_size(items)
  local max_w = cfg.dropdown.min_width
  local arrow_w = #pattern.menu.submenu_arrow[1] + dpi(8)
  local toggles, img_width = has_toggles(items)

  local tog_sp = 0
  if toggles then
    if img_width > 0 then
      tog_sp = img_width + dpi(8)
    else
      tog_sp = cfg.dropdown.indicator_width
    end
  end

  for _, v in ipairs(items) do
    if not v.separator then
      local tw = measure(v.text or "")
      local rw = v.text_right and (measure(v.text_right) + dpi(16)) or 0
      local extra = v.submenu and arrow_w or 0
      max_w = math.max(max_w, tw + rw + cfg.dropdown.padding_x * 2 + extra + tog_sp)
    end
  end

  local h = 0
  for _, v in ipairs(items) do
    if v.separator then
      h = h + cfg.dropdown.separator_gap * 2 + cfg.dropdown.dot_size
    else
      h = h + cfg.dropdown.item_height
    end
  end

  return max_w, h, toggles, tog_sp
end

local function draw_item(cr, pango, item, y, w, hovered, tog_sp)
  local disabled = item.enabled == false
  local tx = cfg.dropdown.padding_x + tog_sp
  local g = cfg.dropdown.disabled_color

  if hovered and not item.nonselectable then
    cr:set_source_rgb(0, 0, 0)
    cr:rectangle(dpi(1), y, w - dpi(2), cfg.dropdown.item_height)
    cr:fill()
    cr:set_source_rgb(1, 1, 1)
  elseif disabled then
    cr:set_source_rgb(g, g, g)
  else
    cr:set_source_rgb(0, 0, 0)
  end

  if item.images then
    local inverted = hovered and not item.nonselectable
    local ix = cfg.dropdown.padding_x

    for _, img in ipairs(item.images) do
      if type(img) == "string" then
        local surface = load_image(img, inverted)
        if surface then
          local img_h = surface:get_height()
          local iy = y + math.floor((cfg.dropdown.item_height - img_h) / 2)
          cr:save()
          cr:set_source_surface(surface, ix, iy)
          cr:paint()
          cr:restore()
        end
      elseif type(img) == "table" then
        if inverted then
          cr:set_source_rgb(1, 1, 1)
        else
          cr:set_source_rgb(0, 0, 0)
        end
        local pat_iy = y + math.floor((cfg.dropdown.item_height - (#img * dpi(1))) / 2)
        pattern.draw(cr, img, ix, pat_iy, dpi(1))
      end
    end
  elseif item.checked == true then
    local l = Pango.Layout.new(pango)
    l:set_font_description(Pango.FontDescription.from_string(cfg.font))
    l:set_text("✓", -1)
    cr:move_to(cfg.dropdown.padding_x, y + dpi(2))
    PangoCairo.show_layout(cr, l)
  elseif item.radio ~= nil then
    local pat = item.radio and pattern.menu.radio_filled or pattern.menu.radio_empty
    local iy = y + math.floor((cfg.dropdown.item_height - (#pat * dpi(1))) / 2)
    pattern.draw(cr, pat, cfg.dropdown.padding_x, iy, dpi(1))
  end

  local l = Pango.Layout.new(pango)
  l:set_font_description(Pango.FontDescription.from_string(cfg.font))
  l:set_text(item.text or "", -1)
  cr:move_to(tx, y + dpi(2))
  PangoCairo.show_layout(cr, l)

  if item.text_right then
    local lr = Pango.Layout.new(pango)
    lr:set_font_description(Pango.FontDescription.from_string(cfg.font))
    lr:set_text(item.text_right, -1)
    local rw = lr:get_pixel_size()
    cr:move_to(w - rw - cfg.dropdown.padding_x, y + dpi(2))
    PangoCairo.show_layout(cr, lr)
  end

  if item.submenu then
    local arrow = pattern.menu.submenu_arrow
    local ax = w - (#arrow[1] * dpi(1)) - cfg.dropdown.padding_x / 2
    local ay = y + math.floor((cfg.dropdown.item_height - (#arrow * dpi(1))) / 2)
    pattern.draw(cr, arrow, ax, ay, dpi(1))
  end
end

local function make_dd(level)
  local widget = wibox.widget.base.make_widget()

  function widget:fit(_, w, h)
    return w, h
  end

  function widget:draw(_, cr, w, h)
    cr:set_font_options(fopts)
    cr:set_source_rgb(1, 1, 1)
    cr:paint()

    cr:set_source_rgb(0, 0, 0)
    cr:set_line_width(dpi(1))
    cr:move_to(1, 0)
    cr:line_to(1, h)
    cr:line_to(w - 1, h)
    cr:line_to(w - 1, 1)
    cr:stroke()

    local e = stack[level]
    if not e or not e.items then return end

    local p = PangoCairo.create_context(cr)
    PangoCairo.context_set_font_options(p, fopts)

    local y = 0
    for i, v in ipairs(e.items) do
      if v.separator then
        local ly = y + cfg.dropdown.separator_gap + 0.5
        cr:set_source_rgb(0, 0, 0)
        cr:set_line_width(cfg.dropdown.dot_size)
        cr:set_dash({ cfg.dropdown.dot_size, cfg.dropdown.dot_size }, 0)
        cr:move_to(dpi(1), ly)
        cr:line_to(w - dpi(1), ly)
        cr:stroke()
        cr:set_dash({}, 0)
        y = y + cfg.dropdown.separator_gap * 2 + cfg.dropdown.dot_size
      else
        draw_item(cr, p, v, y, w, e.hovered == i, e.has_toggles)
        y = y + cfg.dropdown.item_height
      end
    end
  end

  return widget
end

local function get_dd(level)
  if not pool[level] then
    pool[level] = wibox({
      ontop = true,
      visible = false,
      bg = "#ffffff",
      type = "popup_menu",
      widget = make_dd(level),
    })
  end
  return pool[level]
end

local function item_y(items, idx)
  local y = 0
  for i = 1, idx - 1 do
    local v = items[i]
    if v.separator then
      y = y + cfg.dropdown.separator_gap * 2 + cfg.dropdown.dot_size
    else
      y = y + cfg.dropdown.item_height
    end
  end
  return y
end

local function close_from(level)
  for i = #stack, level, -1 do
    if stack[i] then
      stack[i].dropdown.visible = false
      stack[i] = nil
    end
  end
end

local function redraw()
  if bar then bar.widget:emit_signal("widget::redraw_needed") end
  for _, e in pairs(stack) do
    if e and e.dropdown then
      e.dropdown.widget:emit_signal("widget::redraw_needed")
    end
  end
end

local function open_sub(level, items, x, y, parent_idx)
  close_from(level)

  local dd = get_dd(level)
  local w, h, toggles, tog_sp = dd_size(items)

  local geo = screen.primary.geometry
  if x + w > geo.x + geo.width then
    if level > 1 and stack[level - 1] then
      x = stack[level - 1].x - w + dpi(2)
    else
      x = geo.x + geo.width - w
    end
  end
  if y + h > geo.y + geo.height then
    y = geo.y + geo.height - h
  end

  dd:geometry({
    x = x,
    y = y,
    width = math.max(w, 1),
    height = math.max(h, 1),
  })

  stack[level] = {
    dropdown = dd,
    items = items,
    hovered = nil,
    x = x,
    y = y,
    width = w,
    height = h,
    parent_idx = parent_idx,
    has_toggles = tog_sp,
  }

  dd.visible = true
  redraw()
end

local function close_all()
  if timer then
    timer:stop()
    timer = nil
  end
  close_from(1)
  stack = {}
  active_tool = nil
  redraw()
end

local function hovered_at(level, mx, my)
  local e = stack[level]
  if not e then return nil end

  if mx < e.x or mx >= e.x + e.width then return nil end
  if my < e.y or my >= e.y + e.height then return nil end

  local ly = my - e.y
  local y = 0

  for i, v in ipairs(e.items) do
    local ih
    if v.separator then
      ih = cfg.dropdown.separator_gap * 2 + cfg.dropdown.dot_size
    else
      ih = cfg.dropdown.item_height
    end

    if ly >= y and ly < y + ih then
      if not v.separator then
        return i
      else
        return nil
      end
    end
    y = y + ih
  end

  return nil
end

local function sched_sub(level, item, idx, entry)
  if timer then
    timer:stop()
    timer = nil
  end

  timer = gears.timer.start_new(cfg.dropdown.submenu_delay, function()
    timer = nil
    local sx = entry.x + entry.width - dpi(2)
    local sy = entry.y + item_y(entry.items, idx)
    open_sub(level + 1, item.submenu, sx, sy, idx)
    return false
  end)
end

local function make_bar()
  local widget = wibox.widget.base.make_widget()

  function widget:fit(_, w, h)
    return w, h
  end

  function widget:draw(_, cr, w, h)
    cr:set_font_options(fopts)
    cr:set_source_rgb(1, 1, 1)
    cr:paint()

    cr:set_source_rgb(0, 0, 0)
    cr:rectangle(0, h - dpi(1), w, dpi(1))
    cr:fill()

    local p = PangoCairo.create_context(cr)
    PangoCairo.context_set_font_options(p, fopts)

    local x = cfg.padding_x
    extents = {}

    local active_menu = nil
    if stack[1] and not active_tool then
      for _, m in ipairs(menus) do
        if m.items == stack[1].items then
          active_menu = m
          break
        end
      end
    end

    for i, m in ipairs(menus) do
      local l = Pango.Layout.new(p)
      l:set_font_description(Pango.FontDescription.from_string(cfg.font))
      l:set_text(m.title or "", -1)

      local tw = l:get_pixel_size()

      extents[i] = {
        x = x - cfg.item_gap / 2,
        width = tw + cfg.item_gap,
        highlight_x = x - cfg.menu_padding,
        menu = m,
      }

      if active_menu == m then
        cr:set_source_rgb(0, 0, 0)
        cr:rectangle(x - cfg.menu_padding, 0, tw + cfg.menu_padding * 2, h - dpi(1))
        cr:fill()
        cr:set_source_rgb(1, 1, 1)
      else
        cr:set_source_rgb(0, 0, 0)
      end

      cr:move_to(x, dpi(2))
      PangoCairo.show_layout(cr, l)
      x = x + tw + cfg.item_gap
    end

    tool_extents = {}
    local rx = w - cfg.padding_x

    for i = #tools, 1, -1 do
      local t = tools[i]
      if t.draw then
        local is_active = active_tool == t

        cr:save()

        local measure_s = cairo.ImageSurface.create(cairo.Format.ARGB32, 1000, h)
        local measure_cr = cairo.Context.create(measure_s)
        measure_cr:set_font_options(fopts)
        local measure_pango = PangoCairo.create_context(measure_cr)
        PangoCairo.context_set_font_options(measure_pango, fopts)
        local tw = t.draw(measure_cr, h, is_active, measure_pango) or 0
        measure_s:finish()

        local tx = rx - tw

        tool_extents[i] = {
          x = tx - cfg.item_gap / 2,
          width = tw + cfg.item_gap,
          highlight_x = tx - cfg.menu_padding,
          tool = t,
          real_x = tx,
          real_width = tw,
        }

        if is_active then
          cr:set_source_rgb(0, 0, 0)
          cr:rectangle(tx - cfg.menu_padding, 0, tw + cfg.menu_padding * 2, h - dpi(1))
          cr:fill()
        end

        cr:translate(tx, 0)
        local tool_pango = PangoCairo.create_context(cr)
        PangoCairo.context_set_font_options(tool_pango, fopts)
        t.draw(cr, h, is_active, tool_pango)

        cr:restore()
        rx = tx - cfg.item_gap
      end
    end
  end

  return widget
end

local function menu_at(x)
  for _, e in ipairs(extents) do
    if x >= e.x and x < e.x + e.width then
      return e.menu, e.highlight_x
    end
  end
  return nil, nil
end

local function tool_at(x)
  for _, e in pairs(tool_extents) do
    if x >= e.x and x < e.x + e.width then
      return e.tool, e.highlight_x
    end
  end
  return nil, nil
end

local function interact_menu(menu, hx)
  if not menu.items then return end

  local geo = bar:geometry()
  open_sub(1, menu.items, geo.x + hx, geo.y + cfg.height, nil)

  mousegrabber.run(function(m)
    local bg = bar:geometry()

    if m.y >= bg.y and m.y < bg.y + cfg.height then
      local hm, hhx = menu_at(m.x - bg.x)
      local ht, htx = tool_at(m.x - bg.x)

      if hm and hm.items then
        local cur = stack[1] and stack[1].items
        if hm.items ~= cur then
          if timer then
            timer:stop()
            timer = nil
          end
          close_from(1)
          active_tool = nil
          open_sub(1, hm.items, bg.x + hhx, bg.y + cfg.height, nil)
        end
      elseif ht and ht.items then
        local cur = stack[1] and stack[1].items
        if ht.items ~= cur then
          if timer then
            timer:stop()
            timer = nil
          end
          close_from(1)
          active_tool = ht
          open_sub(1, ht.items, bg.x + htx, bg.y + cfg.height, nil)
        end
      end

      for _, e in pairs(stack) do
        if e then e.hovered = nil end
      end
      redraw()
    else
      local fl, fi = nil, nil

      for lv = #stack, 1, -1 do
        local idx = hovered_at(lv, m.x, m.y)
        if idx then
          fl, fi = lv, idx
          break
        end
      end

      if fl then
        local e = stack[fl]
        local v = e.items[fi]

        local old = e.hovered

        if v.nonselectable then
          e.hovered = nil
        else
          e.hovered = fi
        end

        for lv = fl + 1, #stack do
          if stack[lv] then
            stack[lv].hovered = nil
          end
        end

        for lv = 1, fl - 1 do
          if stack[lv] then
            local dom = stack[lv + 1] and stack[lv + 1].parent_idx == stack[lv].hovered
            if not dom then
              stack[lv].hovered = nil
            end
          end
        end

        if v.submenu and not v.nonselectable then
          local open = stack[fl + 1] and stack[fl + 1].parent_idx == fi
          if not open and old ~= fi then
            sched_sub(fl, v, fi, e)
          end
        else
          if timer then
            timer:stop()
            timer = nil
          end
          close_from(fl + 1)
        end

        redraw()
      else
        local changed = false
        for lv = 1, #stack do
          local e = stack[lv]
          if e and e.hovered then
            local child = stack[lv + 1] and stack[lv + 1].parent_idx == e.hovered
            if not child then
              e.hovered = nil
              changed = true
            end
          end
        end
        if changed then redraw() end
      end
    end

    if not m.buttons[1] then
      local sel = nil
      for lv = #stack, 1, -1 do
        local e = stack[lv]
        if e and e.hovered then
          local v = e.items[e.hovered]
          if v and not v.submenu and not v.nonselectable then
            sel = v
            break
          end
        end
      end

      if timer then
        timer:stop()
        timer = nil
      end

      close_all()

      if sel and sel.on_click then
        sel.on_click()
      end

      return false
    end

    return true
  end, "left_ptr")
end

local function interact_tool(tool, hx)
  if not tool.items then
    if tool.on_click then
      tool.on_click()
    end
    return
  end

  local geo = bar:geometry()
  active_tool = tool
  open_sub(1, tool.items, geo.x + hx, geo.y + cfg.height, nil)

  mousegrabber.run(function(m)
    local bg = bar:geometry()

    if m.y >= bg.y and m.y < bg.y + cfg.height then
      local hm, hhx = menu_at(m.x - bg.x)
      local ht, htx = tool_at(m.x - bg.x)

      if hm and hm.items then
        local cur = stack[1] and stack[1].items
        if hm.items ~= cur then
          if timer then
            timer:stop()
            timer = nil
          end
          close_from(1)
          active_tool = nil
          open_sub(1, hm.items, bg.x + hhx, bg.y + cfg.height, nil)
        end
      elseif ht and ht.items then
        local cur = stack[1] and stack[1].items
        if ht.items ~= cur then
          if timer then
            timer:stop()
            timer = nil
          end
          close_from(1)
          active_tool = ht
          open_sub(1, ht.items, bg.x + htx, bg.y + cfg.height, nil)
        end
      end

      for _, e in pairs(stack) do
        if e then e.hovered = nil end
      end
      redraw()
    else
      local fl, fi = nil, nil

      for lv = #stack, 1, -1 do
        local idx = hovered_at(lv, m.x, m.y)
        if idx then
          fl, fi = lv, idx
          break
        end
      end

      if fl then
        local e = stack[fl]
        local v = e.items[fi]

        local old = e.hovered

        if v.nonselectable then
          e.hovered = nil
        else
          e.hovered = fi
        end

        for lv = fl + 1, #stack do
          if stack[lv] then
            stack[lv].hovered = nil
          end
        end

        for lv = 1, fl - 1 do
          if stack[lv] then
            local dom = stack[lv + 1] and stack[lv + 1].parent_idx == stack[lv].hovered
            if not dom then
              stack[lv].hovered = nil
            end
          end
        end

        if v.submenu and not v.nonselectable then
          local open = stack[fl + 1] and stack[fl + 1].parent_idx == fi
          if not open and old ~= fi then
            sched_sub(fl, v, fi, e)
          end
        else
          if timer then
            timer:stop()
            timer = nil
          end
          close_from(fl + 1)
        end

        redraw()
      else
        local changed = false
        for lv = 1, #stack do
          local e = stack[lv]
          if e and e.hovered then
            local child = stack[lv + 1] and stack[lv + 1].parent_idx == e.hovered
            if not child then
              e.hovered = nil
              changed = true
            end
          end
        end
        if changed then redraw() end
      end
    end

    if not m.buttons[1] then
      local sel = nil
      for lv = #stack, 1, -1 do
        local e = stack[lv]
        if e and e.hovered then
          local v = e.items[e.hovered]
          if v and not v.submenu and not v.nonselectable then
            sel = v
            break
          end
        end
      end

      if timer then
        timer:stop()
        timer = nil
      end

      close_all()

      if sel and sel.on_click then
        sel.on_click()
      end

      return false
    end

    return true
  end, "left_ptr")
end

function topbar.set_menus(m)
  menus = m
  if bar then
    bar.widget:emit_signal("widget::redraw_needed")
  end
end

function topbar.set_tools(t)
  tools = t
  if bar then
    bar.widget:emit_signal("widget::redraw_needed")
  end
end

function topbar.clock_tool()
  local clock_text = ""

  local function tick()
    clock_text = tostring(os.date("%I:%M %p"))
    if clock_text:sub(1, 1) == "0" then
      clock_text = clock_text:sub(2)
    end
    if bar then
      bar.widget:emit_signal("widget::redraw_needed")
    end
  end

  tick()
  gears.timer({
    timeout = 1,
    autostart = true,
    call_now = true,
    callback = tick
  })

  return {
    draw = function(cr, _, is_active, pango)
      local l = Pango.Layout.new(pango)
      l:set_font_description(Pango.FontDescription.from_string(cfg.font))
      l:set_text(clock_text, -1)

      local tw = l:get_pixel_size()

      if is_active then
        cr:set_source_rgb(1, 1, 1)
      else
        cr:set_source_rgb(0, 0, 0)
      end

      cr:move_to(0, dpi(2))
      PangoCairo.show_layout(cr, l)

      return tw
    end,
  }
end

function topbar.init(args)
  args = args or {}
  local s = args.screen or screen.primary

  bar = wibox({
    screen = s,
    x = s.geometry.x,
    y = s.geometry.y,
    width = s.geometry.width,
    height = cfg.height,
    visible = true,
    ontop = true,
    bg = "#ffffff",
    type = "dock",
    widget = make_bar(),
  })

  bar:struts({ top = cfg.height })

  bar:connect_signal("button::press", function(_, lx, _, button)
    if button == 1 then
      local m, hx = menu_at(lx)
      local t, tx = tool_at(lx)

      if m and m.items then
        interact_menu(m, hx)
      elseif m and m.on_click then
        m.on_click()
      elseif t then
        interact_tool(t, tx)
      end
    end
  end)

  return bar
end

topbar.load_image = load_image

function topbar.redraw()
  if bar then
    bar.widget:emit_signal("widget::redraw_needed")
  end
end

return topbar
