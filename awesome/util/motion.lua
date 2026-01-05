local motion = {}

awesome.register_xproperty("_OUTLINE_ACTIVE", "string")
awesome.register_xproperty("_VISIBLE", "string")

motion.ANIM_LENGTH = 0.3

local function create_outline_widget(parent)
  local widget = wibox.widget.base.make_widget()

  function widget:fit(_, w, h)
    return w, h
  end

  function widget:draw(_, cr, w, h)
    local visible = parent.drawin:get_xproperty("_VISIBLE") or "false"
    if visible ~= "true" then return end

    cr:set_source_rgb(0, 0, 0)
    cr:set_line_width(dpi(1))
    cr:rectangle(0, 0, w, h)
    cr:stroke()
  end

  return widget
end

function motion.create_outline(x, y, w, h, prop)
  prop = prop or "_OUTLINE_ACTIVE"
  local outline = wibox({
    bg = "#00000000",
    type = "utility",
    visible = true,
    x = x,
    y = y,
    width = w,
    height = h,
    input_passthrough = true,
    ontop = true,
  })
  outline.widget = create_outline_widget(outline)
  outline.drawin:set_xproperty(prop, "true")
  outline.drawin:set_xproperty("_VISIBLE", "false")

  return outline
end

function motion.show(outline)
  outline.drawin:set_xproperty("_VISIBLE", "true")
end

function motion.hide(outline)
  outline.visible = false
end

function motion.animate_to_client(outline, c, callback)
  motion.show(outline)

  gears.timer.delayed_call(function()
    local geo = c:geometry()

    local offset = 0
    if c.titlebars_enabled then offset = dpi(18) end

    outline:geometry({
      x = geo.x,
      y = geo.y,
      width = geo.width,
      height = geo.height + offset,
    })

    gears.timer.start_new(motion.ANIM_LENGTH, function()
      outline.visible = false
      if callback then callback() end
      return false
    end)
  end)
end

function motion.animate_to_geometry(outline, geo, callback)
  motion.show(outline)

  gears.timer.delayed_call(function()
    outline:geometry(geo)

    gears.timer.start_new(motion.ANIM_LENGTH, function()
      outline.visible = false
      if callback then callback() end
      return false
    end)
  end)
end

return motion
