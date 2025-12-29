local pattern = {}

pattern.titlebar = {
  maximize_idle = {
    { 1, 1, 1, 1, 1, 0, 1, 1, 1 },
    { 1, 1, 1, 1, 1, 0, 1, 1, 1 },
    { 1, 1, 1, 1, 1, 0, 1, 1, 1 },
    { 1, 1, 1, 1, 1, 0, 1, 1, 1 },
    { 1, 1, 1, 1, 1, 0, 1, 1, 1 },
    { 0, 0, 0, 0, 0, 0, 1, 1, 1 },
    { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
  },
  pressed = {
    { 1, 1, 1, 1, 0, 1, 1, 1, 1 },
    { 1, 0, 1, 1, 0, 1, 1, 0, 1 },
    { 1, 1, 0, 1, 0, 1, 0, 1, 1 },
    { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    { 0, 0, 0, 1, 1, 1, 0, 0, 0 },
    { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    { 1, 1, 0, 1, 0, 1, 0, 1, 1 },
    { 1, 0, 1, 1, 0, 1, 1, 0, 1 },
    { 1, 1, 1, 1, 0, 1, 1, 1, 1 },
  },
}

pattern.menu = {
  radio_empty = {
    { 1, 1, 0, 0, 0, 0, 0, 1, 1 },
    { 1, 0, 1, 1, 1, 1, 1, 0, 1 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 1, 0, 1, 1, 1, 1, 1, 0, 1 },
    { 1, 1, 0, 0, 0, 0, 0, 1, 1 },
  },
  radio_filled = {
    { 1, 1, 0, 0, 0, 0, 0, 1, 1 },
    { 1, 0, 1, 1, 1, 1, 1, 0, 1 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 0, 1, 1, 0, 0, 0, 1, 1, 0 },
    { 0, 1, 1, 0, 0, 0, 1, 1, 0 },
    { 0, 1, 1, 0, 0, 0, 1, 1, 0 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 1, 0, 1, 1, 1, 1, 1, 0, 1 },
    { 1, 1, 0, 0, 0, 0, 0, 1, 1 },
  },
  submenu_arrow = {
    { 0, 1, 1, 1 },
    { 0, 0, 1, 1 },
    { 0, 0, 0, 1 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 1 },
    { 0, 0, 1, 1 },
    { 0, 1, 1, 1 },
  },
}

local dither_surface = nil
local dither_cairo_pattern = nil

function pattern.get_dither()
  if not dither_cairo_pattern then
    dither_surface = cairo.ImageSurface.create(cairo.Format.A8, 2, 2)
    local cr = cairo.Context.create(dither_surface)
    cr:set_source_rgba(0, 0, 0, 1)
    cr:rectangle(0, 0, 1, 1)
    cr:fill()
    cr:rectangle(1, 1, 1, 1)
    cr:fill()
    dither_cairo_pattern = cairo.Pattern.create_for_surface(dither_surface)
    dither_cairo_pattern:set_extend(cairo.Extend.REPEAT)
  end
  return dither_cairo_pattern
end

function pattern.draw(cr, pat, x, y, scale)
  scale = scale or 1
  for row = 1, #pat do
    for col = 1, #pat[row] do
      if pat[row][col] == 0 then
        cr:rectangle(x + (col - 1) * scale, y + (row - 1) * scale, scale, scale)
      end
    end
  end
  cr:fill()
end

function pattern.draw_opaque(cr, pat, x, y, scale)
  scale = scale or 1
  for row = 1, #pat do
    for col = 1, #pat[row] do
      local val = pat[row][col]
      cr:set_source_rgb(val, val, val)
      cr:rectangle(x + (col - 1) * scale, y + (row - 1) * scale, scale, scale)
      cr:fill()
    end
  end
end

function pattern.with_dither(cr, fn)
  cr:push_group()
  fn()
  local group = cr:pop_group()
  cr:set_source(group)
  cr:mask(pattern.get_dither())
end

function pattern.size(pat, scale)
  scale = scale or 1
  return #pat[1] * scale, #pat * scale
end

return pattern
