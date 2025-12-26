Each_screen(function(s)
  local si = s.index
  awful.tag({ si .. "-1", si .. "-2", si .. "-3", si .. "-4", si .. "-5" }, s, awful.layout.layouts[1])
end)
