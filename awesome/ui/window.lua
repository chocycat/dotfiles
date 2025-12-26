client.connect_signal("focus", function(c)
  if c.border_width == 0 then return end
  c.border_color = beautiful.border_focus
end)

client.connect_signal("unfocus", function(c)
  if c.border_width == 0 then return end
  c.border_color = beautiful.border_normal
end)
