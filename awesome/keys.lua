local SUPER_KEY = "Mod4"
local SOFTWARE = {
  TERMINAL = "st",
  EDITOR = "vim"
}

local global_keys = gears.table.join(
  awful.key({ SUPER_KEY }, "Return", function() awful.spawn(SOFTWARE.TERMINAL) end,
    { description = "spawn terminal", group = "launcher" }),
  awful.key({ SUPER_KEY, "Control" }, "r", awesome.restart, { description = "quit awesome", group = "awesome" }),
  awful.key({ SUPER_KEY, "Control" }, "x", awesome.quit, { description = "reload awesome", group = "awesome" })
)

root.keys(global_keys)
