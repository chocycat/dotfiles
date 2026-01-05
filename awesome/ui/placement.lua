local M = {}

M.config = {
  padding = dpi(10),
  position_bias_weight = 0.01,
  overlap_threshold = 0.6,
  cascade_offset_x = dpi(24),
  cascade_offset_y = dpi(24),
}

local cascade_indices = setmetatable({}, { __mode = "k" })

local function intersect_area(r1, r2)
  local x_overlap = math.max(0, math.min(r1.x + r1.width, r2.x + r2.width) - math.max(r1.x, r2.x))
  local y_overlap = math.max(0, math.min(r1.y + r1.height, r2.y + r2.height) - math.max(r1.y, r2.y))
  return x_overlap * y_overlap
end

local function rect_area(r)
  return r.width * r.height
end

local function clamp(val, min_val, max_val)
  return math.max(min_val, math.min(max_val, val))
end

local function get_clients(target_client)
  local dominated = {}
  local dominated_floating = {}
  local dominated_fullscreen = nil

  local dominated_screen = target_client.screen
  local dominated_tags = target_client:tags()

  for _, c in ipairs(client.get()) do
    if c ~= target_client
        and c.screen == dominated_screen
        and c:isvisible()
        and not c.minimized
        and c.type ~= "desktop"
        and c.type ~= "dock"
        and c.type ~= "splash"
        and c.name ~= "system::desktop"
    then
      local dominated_tag = false
      for _, t in ipairs(dominated_tags) do
        if c:tags()[1] == t or awful.widget.taglist.filter.all() then
          dominated_tag = true
          break
        end
      end

      if dominated_tag then
        if c.fullscreen then
          dominated_fullscreen = c
        elseif c.floating or awful.layout.get(dominated_screen) == awful.layout.suit.floating then
          table.insert(dominated_floating, c)
        else
          table.insert(dominated, c)
        end
      end
    end
  end

  if dominated_fullscreen then
    return { dominated_fullscreen }
  end

  local effective_list = {}
  for _, c in ipairs(dominated_floating) do
    table.insert(effective_list, c)
  end

  for _, c in ipairs(dominated) do
    table.insert(effective_list, c)
  end

  return effective_list
end

local function get_candidates(workarea, window_geo, existing_windows, cfg)
  local x_coords = {}
  local y_coords = {}

  local function add_x(x) x_coords[x] = true end
  local function add_y(y) y_coords[y] = true end

  local wa_left = workarea.x + cfg.padding
  local wa_top = workarea.y + cfg.padding
  local wa_right = workarea.x + workarea.width - cfg.padding
  local wa_bottom = workarea.y + workarea.height - cfg.padding

  add_x(wa_left)
  add_y(wa_top)

  add_x(wa_right - window_geo.width)
  add_y(wa_bottom - window_geo.height)

  add_x(workarea.x + (workarea.width - window_geo.width) / 2)
  add_y(workarea.y + (workarea.height - window_geo.height) / 2)

  for _, c in ipairs(existing_windows) do
    local geo = c:geometry()

    add_x(geo.x + geo.width + cfg.padding)
    add_x(geo.x - window_geo.width - cfg.padding)
    add_x(geo.x)
    add_x(geo.x + geo.width - window_geo.width)

    add_y(geo.y + geo.height + cfg.padding)
    add_y(geo.y - window_geo.height - cfg.padding)
    add_y(geo.y)
    add_y(geo.y + geo.height - window_geo.height)
  end

  local candidates = {}
  local min_x = wa_left
  local max_x = wa_right - window_geo.width
  local min_y = wa_top
  local max_y = wa_bottom - window_geo.height

  for x, _ in pairs(x_coords) do
    for y, _ in pairs(y_coords) do
      if x >= min_x and x <= max_x and y >= min_y and y <= max_y then
        table.insert(candidates, { x = x, y = y })
      end
    end
  end

  if #candidates == 0 then
    table.insert(candidates, {
      x = clamp(wa_left, min_x, max_x),
      y = clamp(wa_top, min_y, max_y)
    })
  end

  return candidates
end


local function score(x, y, window_geo, existing_windows, workarea, cfg)
  local test_rect = {
    x = x,
    y = y,
    width = window_geo.width,
    height = window_geo.height
  }

  local total_overlap = 0
  for _, c in ipairs(existing_windows) do
    local geo = c:geometry()
    total_overlap = total_overlap + intersect_area(test_rect, geo)
  end

  local norm_x = (x - workarea.x) / workarea.width
  local norm_y = (y - workarea.y) / workarea.height
  local position_penalty = (norm_x + norm_y) * cfg.position_bias_weight * rect_area(window_geo)

  return total_overlap + position_penalty, total_overlap
end

local function get_position(workarea, window_geo, existing_windows, cfg)
  local candidates = get_candidates(workarea, window_geo, existing_windows, cfg)

  local best_pos = nil
  local best_score = math.huge
  local best_overlap = math.huge

  for _, pos in ipairs(candidates) do
    local score, overlap = score(pos.x, pos.y, window_geo, existing_windows, workarea, cfg)
    if score < best_score then
      best_score = score
      best_overlap = overlap
      best_pos = pos
    end
  end

  return best_pos, best_overlap
end

local function cascade(c, workarea, cfg)
  local screen = c.screen
  if not cascade_indices[screen] then
    cascade_indices[screen] = 0
  end

  local geo = c:geometry()

  local max_cascade_x = math.floor((workarea.width - geo.width - cfg.padding * 2) / cfg.cascade_offset_x)
  local max_cascade_y = math.floor((workarea.height - geo.height - cfg.padding * 2) / cfg.cascade_offset_y)
  local max_cascade = math.max(1, math.min(max_cascade_x, max_cascade_y))

  local idx = cascade_indices[screen] % max_cascade

  local x = workarea.x + cfg.padding + (idx * cfg.cascade_offset_x)
  local y = workarea.y + cfg.padding + (idx * cfg.cascade_offset_y)

  cascade_indices[screen] = cascade_indices[screen] + 1

  return { x = x, y = y }
end

function M.placement(c)
  if c.type == "utility" or c.type == "desktop" or c.type == "dock" or c.type == "splash" then
    return
  end

  if c.requests_no_placement then
    return
  end

  local cfg = M.config
  local workarea = c.screen.workarea
  local geo = c:geometry()

  if geo.width > workarea.width - cfg.padding * 2 then
    geo.width = workarea.width - cfg.padding * 2
  end
  if geo.height > workarea.height - cfg.padding * 2 then
    geo.height = workarea.height - cfg.padding * 2
  end

  local existing = get_clients(c)

  if #existing == 0 then
    c:geometry({
      x = workarea.x + cfg.padding,
      y = workarea.y + cfg.padding,
      width = geo.width,
      height = geo.height
    })
    return
  end

  local best_pos, best_overlap = get_position(workarea, geo, existing, cfg)
  local window_area = rect_area(geo)

  if best_overlap > window_area * cfg.overlap_threshold then
    best_pos = cascade(c, workarea, cfg)
  end

  if best_pos then
    c:geometry({
      x = best_pos.x,
      y = best_pos.y,
      width = geo.width,
      height = geo.height
    })
  end
end

function M.reset_cascade(screen)
  cascade_indices[screen] = 0
end

return M
