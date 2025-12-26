---@diagnostic disable: lowercase-global

pcall(require, "luarocks.loader")

require("util.composables")

require("awful.autofocus")
require("awful.hotkeys_popup.keys")

require("theme")
require("environment")
require("ui")

function __goto_tag(screeni, tagi)
  local s = screen[screeni]
  local tag = s.tags[tagi]
  if tag then
    ViewTag(tag)
  end
end

function __goto_client(id)
  for _, c in ipairs(client.get()) do
    if tostring(c.window) == tostring(id) then
      awful.screen.focus(c.screen)
      local tag = c.first_tag
      if not tag.selected then
        ViewTag(tag)
      end

      c:raise()
      client.focus = c

      break
    end
  end
end

local registered = false
local prev_tags = {}

function ViewTag(t)
  if not t then return end

  if not registered then
    awesome.register_xproperty("_NET_WM_TRANSITION", "string")
    registered = true
  end

  local c_screen = t.screen
  local c_idx = t.index
  local prev_tag = prev_tags[c_screen]

  if prev_tag and prev_tag.screen == c_screen then
    local prev_idx = prev_tag.index
    if c_idx < prev_idx then
      for _, c in ipairs(t:clients()) do
        c:set_xproperty("_NET_WM_TRANSITION", "_NET_WM_TRANSITION_LEFT_SHOW");
      end

      for _, c in ipairs(prev_tag:clients()) do
        c:set_xproperty("_NET_WM_TRANSITION", "_NET_WM_TRANSITION_RIGHT_HIDE");
      end
    elseif c_idx > prev_idx then
      for _, c in ipairs(t:clients()) do
        c:set_xproperty("_NET_WM_TRANSITION", "_NET_WM_TRANSITION_RIGHT_SHOW")
      end

      for _, c in ipairs(prev_tag:clients()) do
        c:set_xproperty("_NET_WM_TRANSITION", "_NET_WM_TRANSITION_LEFT_HIDE")
      end
    end
  end

  t:view_only()

  prev_tags[c_screen] = t
end
