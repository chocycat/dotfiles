local wallpaper = {}

wallpaper.scale = 2
wallpaper.patterns = {
  checkerboard = {
    { 1, 0 },
    { 0, 1 },
  }
}


local function create_surface(pattern, fg, bg)
  local scale = wallpaper.scale
  local size = #pattern * scale

  local surface = cairo.ImageSurface.create(cairo.Format.RGB24, size, size)
  local cr = cairo.Context.create(surface)

  local fg_r, fg_g, fg_b = gears.color.parse_color(fg or "#000000")
  local bg_r, bg_g, bg_b = gears.color.parse_color(bg or "#ffffff")

  for y = 1, #pattern do
    for x = 1, #pattern do
      if pattern[y][x] == 1 then
        cr:set_source_rgb(bg_r, bg_g, bg_b)
      else
        cr:set_source_rgb(fg_r, fg_g, fg_b)
      end
      cr:rectangle((x - 1) * scale, (y - 1) * scale, scale, scale)
      cr:fill()
    end
  end

  return surface
end

function wallpaper.set(s, pattern, fg, bg)
  pattern = pattern or wallpaper.patterns.checkerboard

  local surface = create_surface(pattern, fg, bg)
  local pattern_c = cairo.Pattern.create_for_surface(surface)
  pattern_c:set_extend(cairo.Extend.REPEAT)

  local geom = s.geometry

  local wp_surface = cairo.ImageSurface.create(cairo.Format.RGB24, geom.width, geom.height)
  local cr = cairo.Context.create(wp_surface)

  cr:set_source(pattern_c)
  cr:paint()

  gears.wallpaper.maximized(wp_surface, s, false)
end

return wallpaper
