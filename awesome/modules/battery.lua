local lgi = require("lgi")
local Gio = lgi.Gio
local topbar = require("ui.topbar")

local M = {}

local PATH = "/sys/class/power_supply/"
local INTERVAL = 10

local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content and content:gsub("%s+$", "") or nil
end

local function is_battery(name)
  local type_path = PATH .. name .. "/type"
  local type_content = read_file(type_path)
  return type_content and type_content:lower() == "battery"
end

local function get_batteries()
  local batteries = {}
  local dir = Gio.File.new_for_path(PATH)
  local enumerator = dir:enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE)

  if enumerator then
    while true do
      local info = enumerator:next_file()
      if not info then break end
      local name = info:get_name()
      if is_battery(name) then
        table.insert(batteries, name)
      end
    end
    enumerator:close()
  end

  return batteries
end

local function get_status_text(name)
  local base = PATH .. name .. "/"

  local status = read_file(base .. "status") or "Unknown"
  local capacity_str = read_file(base .. "capacity")
  local capacity = capacity_str and tonumber(capacity_str) or 0

  return {
    name = name,
    status = status,
    capacity = capacity,
  }
end

local function get_primary(batteries_data)
  if #batteries_data == 0 then return nil end
  if #batteries_data == 1 then return batteries_data[1] end

  local discharging = {}
  local charging = {}
  local other = {}

  for _, bat in ipairs(batteries_data) do
    if bat.status == "Discharging" then
      table.insert(discharging, bat)
    elseif bat.status == "Charging" then
      table.insert(charging, bat)
    else
      table.insert(other, bat)
    end
  end

  if #discharging > 0 then
    table.sort(discharging, function(a, b) return a.capacity < b.capacity end)
    return discharging[1]
  end

  if #charging > 0 then
    table.sort(charging, function(a, b) return a.capacity < b.capacity end)
    return charging[1]
  end

  table.sort(other, function(a, b) return a.capacity < b.capacity end)
  return other[1]
end

local function get_images(bat)
  local images = {}

  local base_idx = math.floor(bat.capacity / 100 * 32)
  base_idx = math.max(0, math.min(32, base_idx))
  table.insert(images, "assets/bat/bat-def-" .. base_idx .. ".png")

  if bat.capacity == 0 then
    table.insert(images, "assets/bat/bat-dead.png")
  elseif bat.capacity >= 1 and bat.capacity <= 10 and bat.status == "Discharging" then
    table.insert(images, "assets/bat/bat-crit.png")
  elseif bat.status == "Charging" then
    table.insert(images, "assets/bat/bat-charge.png")
  end

  return images
end

local function get_status(bat)
  local status = bat.status
  if status == "Discharging" then
    return "Discharging"
  elseif status == "Charging" then
    return "Charging"
  elseif status == "Full" then
    return "Charged"
  elseif status == "Not charging" then
    return "On AC Power"
  else
    return status
  end
end

function M.create_watcher(callback)
  local batteries_data = {}
  local primary_battery = nil
  local update_timer = nil
  local tool = nil

  local watcher = {
    batteries_data = batteries_data,
    primary_battery = primary_battery,
  }

  local function build()
    local items = {}

    for _, bat in ipairs(watcher.batteries_data) do
      local images = get_images(bat)
      local status_text = get_status_text(bat)
      local percentage = bat.capacity .. "%"

      table.insert(items, {
        text = status_text,
        text_right = percentage,
        images = images,
        nonselectable = true,
      })
    end

    if #items == 0 then
      table.insert(items, {
        text = "No batteries",
        nonselectable = true,
      })
    end

    return items
  end

  local function update()
    local battery_names = get_batteries()
    batteries_data = {}

    for _, name in ipairs(battery_names) do
      local bat = get_status(name)
      table.insert(batteries_data, bat)
    end

    watcher.batteries_data = batteries_data
    watcher.primary_battery = get_primary(batteries_data)

    if tool then
      tool.items = build()
    end

    if callback then
      callback(watcher)
    end
  end

  function watcher:get_tool()
    tool = {
      draw = function(cr, h, is_active)
        local bat = watcher.primary_battery
        if not bat then
          return 0
        end

        local images = get_images(bat)
        local img_w = 0

        for _, img_path in ipairs(images) do
          local img = topbar.load_image(img_path, is_active)
          if img then
            local img_h = img:get_height()
            img_w = math.max(img_w, img:get_width())
            local y = math.floor((h - img_h) / 2)

            cr:set_source_surface(img, 0, y)
            cr:paint()
          end
        end

        return img_w
      end,

      items = build(),
    }

    return tool
  end

  function watcher:stop()
    if update_timer then
      update_timer:stop()
      update_timer = nil
    end
  end

  function watcher:has_batteries()
    return #watcher.batteries_data > 0
  end

  update()

  update_timer = gears.timer({
    timeout = INTERVAL,
    autostart = true,
    call_now = false,
    callback = update
  })

  return watcher
end

return M
