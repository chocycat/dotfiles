local window = {}

local function apply_styles(c)
  c.border_width = dpi(1)
  c.border_color = "#000000"
  c.shape = gears.shape.rectangle
end

function window.init()
  client.connect_signal("manage", function(c)
    apply_styles(c)
  end)

  client.connect_signal("property::maximized", function(c)
    if not c.maximized then
      apply_styles(c)
    end
  end)
end

return window
