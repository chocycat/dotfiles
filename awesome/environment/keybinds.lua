local global_keys = gears.table.join(
-- base bindings
  awful.key({ SUPER_KEY, "Shift" }, "comma", hotkeys_popup.show_help,
    { description = "show help", group = "awesome" }),

  -- client binds
  awful.key({ SUPER_KEY }, "semicolon", function() awful.layout.inc(1) end,
    { description = "select next layout", group = "layout" }),

  -- programs
  awful.key({ SUPER_KEY }, "\\", function() awful.spawn.with_shell(SOFTWARE.SCREENSHOT) end, { group = 'custom' }),
  awful.key({ SUPER_KEY }, "r",
    function() awful.spawn.with_shell('echo "toggle-search" | socat - UNIX-CONNECT:/tmp/polestar.sock') end,
    { group = "custom" }),
  awful.key({ SUPER_KEY, }, "Return", function() awful.spawn(SOFTWARE.TERMINAL) end,
    { description = "open a terminal", group = "launcher" }),
  awful.key({ SUPER_KEY, "Control" }, "r", awesome.restart,
    { description = "reload awesome", group = "awesome" })
)


for i = 1, 5 do
  global_keys = gears.table.join(global_keys,
    -- switch to tag
    awful.key({ SUPER_KEY }, "#" .. i + 9, function()
      local screen = awful.screen.focused()
      local tag = screen.tags[i]
      if tag then
        ViewTag(tag)
      end
    end, { description = "view tag #" .. i, group = "tag" }),

    -- move client to tag
    awful.key({ SUPER_KEY, "Shift" }, "#" .. i + 9, function()
      if client.focus then
        local tag = client.focus.screen.tags[i]
        if tag then
          client.focus:move_to_tag(tag)
          ViewTag(tag)
        end
      end
    end)
  )
end

root.keys(global_keys)
