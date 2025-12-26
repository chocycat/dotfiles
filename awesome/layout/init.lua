local capi = { mouse = mouse, client = client, mousegrabber = mousegrabber }

local tree = require("layout.tree")
local geometry = require("layout.geometry")

local master = {
  tree = tree,
  geometry = geometry
}

local state = {
  trees = setmetatable({}, { __mode = "k" }),
  bounds = setmetatable({}, { __mode = "k" }),
  drag = nil
}

local function get_gap()
  return beautiful.useless_gap or 8
end

local function choose_orientation(w, h)
  return w >= h and tree.HORIZONTAL or tree.VERTICAL
end

local function should_tile(c)
  if c.__dragging then return true end
  if c.floating then return false end
  return true
end

local function sync_tree_removals(tag, root, clients)
  local exists = {}
  for _, c in ipairs(clients) do exists[c] = true end

  local leaves = tree.collect_leaves(root)
  for _, leaf in ipairs(leaves) do
    local c = leaf.client
    if c and not exists[c] then
      if not (c.fullscreen) then
        root = tree.remove_leaf(root, leaf)
        state.trees[tag] = root
        if not root then return nil end
      end
    end
  end
  return root
end

local function sync_tree_additions(tag, root, clients, workarea, gap)
  for _, c in ipairs(clients) do
    if not root then
      root = tree.new_leaf(c)
      state.trees[tag] = root
    elseif not tree.find_leaf(root, c) then
      if should_tile(c) then
        local bounds = geometry.calculate(root, workarea.x, workarea.y, workarea.width, workarea.height, gap)
        local mx, my = capi.mouse.coords().x, capi.mouse.coords().y

        local target, target_bounds = tree.find_leaf_at_point(bounds, mx, my)
        if not target then
          target, target_bounds = tree.find_closest_leaf(bounds, mx, my)
        end

        if target and target_bounds then
          local orientation = choose_orientation(target_bounds.w, target_bounds.h)
          root = tree.insert_at_leaf(root, target, c, orientation)
          state.trees[tag] = root
        end
      end
    end
  end
  return root
end

function master.arrange(params)
  local s = type(params.screen) == "number" and screen[params.screen] or params.screen
  local tag = s.selected_tag
  local workarea = params.workarea
  local gap = get_gap()
  local inner = {
    x = workarea.x + gap,
    y = workarea.y + gap,
    width = workarea.width - (gap * 2),
    height =
        workarea.height - (gap * 2)
  }

  local clients = {}
  for _, c in ipairs(params.clients) do
    if should_tile(c) then
      table.insert(clients, c)
    end
  end

  if state.drag and state.drag.client then
    local dominated = state.drag.client
    if dominated.first_tag == tag then
      local found = false
      for _, c in ipairs(clients) do
        if c == dominated then
          found = true
          break
        end
      end
      if not found then
        table.insert(clients, dominated)
      end
    end
  end


  if #clients == 0 then
    state.bounds[tag] = {}
    return
  end


  local root = state.trees[tag]

  if root then
    root = sync_tree_removals(tag, root, clients)
  end
  root = sync_tree_additions(tag, root, clients, inner, gap)

  if not root then
    state.bounds[tag] = {}
    return
  end

  local skip = state.drag and state.drag.client or nil
  local bounds = geometry.calculate(root, inner.x, inner.y, inner.width, inner.height, gap, nil, skip)
  state.bounds[tag] = bounds

  for _, b in ipairs(bounds) do
    local c = b.leaf.client
    if c and not c.__dragging and not c.fullscreen and not c.zoned and not c.floating then
      c:geometry({ x = b.x, y = b.y, width = b.w, height = b.h })
    elseif c.zoned and not c.fullscreen and not c.floating then
      c:geometry({
        x = inner.x,
        y = inner.y,
        width = inner.width,
        height = inner.height
      })
    end
  end
end

master.layout = {
  name = "master",
  arrange = master.arrange
}

function master.start_drag(c)
  if not c then c = capi.client.focus end
  if not c then return end

  local tag = c.first_tag
  if not tag then return end

  local root = state.trees[tag]
  if not root then return end

  local leaf = tree.find_leaf(root, c)
  if not leaf then return end

  local geom = c:geometry()
  local s = c.screen
  local workarea = s.workarea
  local gap = get_gap()

  local pre_drag_bounds = geometry.calculate(root, workarea.x, workarea.y, workarea.width, workarea.height, gap)
  local original_slot = nil
  for _, b in ipairs(pre_drag_bounds) do
    if b.leaf == leaf then
      original_slot = { x = b.x, y = b.y, w = b.w, h = b.h }
      break
    end
  end

  local float_w, float_h

  local aspect = geom.width / geom.height
  local max_area = 0.25 * workarea.width * workarea.height

  float_h = math.floor(math.sqrt(max_area / aspect))
  float_w = math.floor(aspect * float_h)

  if float_w > geom.width or float_h > geom.height then
    float_w = geom.width
    float_h = geom.height
  end

  local coords = capi.mouse.coords()
  local float_x = math.floor(coords.x - float_w / 2)
  local float_y = math.floor(coords.y - float_h / 2)

  state.drag = {
    client = c,
    tag = tag,
    leaf = leaf,
    original_geom = {
      x = geom.x,
      y = geom.y,
      width = geom.width,
      height = geom.height
    },
    original_slot = original_slot,
    float_w = float_w,
    float_h = float_h,
  }

  c.__dragging = true
  c.floating = true
  c:geometry({ x = float_x, y = float_y, width = float_w, height = float_h })

  awful.layout.arrange(tag.screen)

  capi.mousegrabber.run(function(m)
    if not state.drag then return false end

    c:geometry({
      x = math.floor(m.x - state.drag.float_w / 2),
      y = math.floor(m.y - state.drag.float_h / 2)
    })

    if not m.buttons[1] then
      master.finish_drag()
      return false
    end

    return true
  end, "fleur")
end

function master.finish_drag()
  if not state.drag then return end

  local c = state.drag.client
  local tag = state.drag.tag
  local source_leaf = state.drag.leaf
  local bounds = state.bounds[tag] or {}
  local original_slot = state.drag.original_slot
  local root = state.trees[tag]

  local mx, my = capi.mouse.coords().x, capi.mouse.coords().y

  local in_original_slot = false
  if original_slot then
    in_original_slot = mx >= original_slot.x and mx < original_slot.x + original_slot.w and my >= original_slot.y and
        my < original_slot.y + original_slot.h
  end

  if not in_original_slot then
    local target_leaf, target_bounds = nil, nil
    for _, b in ipairs(bounds) do
      if b.leaf ~= source_leaf and b.leaf.client then
        if mx >= b.x and mx < b.x + b.w and my >= b.y and my < b.y + b.h then
          target_leaf = b.leaf
          target_bounds = b
          break
        end
      end
    end

    if target_leaf and target_bounds then
      local rel_x = (mx - target_bounds.x) / target_bounds.w
      local rel_y = (my - target_bounds.y) / target_bounds.h

      local dx = math.abs(rel_x - 0.5)
      local dy = math.abs(rel_y - 0.5)

      local orientation, position
      if dx > dy then
        orientation = tree.HORIZONTAL
        position = rel_x < 0.5 and "first" or "second"
      else
        orientation = tree.VERTICAL
        position = rel_y < 0.5 and "first" or "second"
      end

      root = tree.remove_leaf(root, source_leaf)
      state.trees[tag] = root

      if root then
        root = tree.insert_at_leaf(root, target_leaf, c, orientation, position)
        state.trees[tag] = root
      else
        root = tree.new_leaf(c)
        state.trees[tag] = root
      end
    end
  end

  c.__dragging = false
  c.floating = false
  state.drag = nil

  awful.layout.arrange(tag.screen)
end

function master.cancel_drag()
  if not state.drag then return end

  local c = state.drag.client
  local tag = state.drag.tag
  local og = state.drag.original_geom

  c.__dragging = false
  c.floating = false
  c:geometry({ x = og.x, y = og.y, width = og.width, height = og.height })

  state.drag = nil
  awful.layout.arrange(tag.screen)
end

function master.resize(c, direction, amount)
  amount = amount or 0.05
  if not c then c = capi.client.focus end
  if not c then return end

  local tag = c.first_tag
  if not tag then return end

  local root = state.trees[tag]
  if not root then return end

  local leaf = tree.find_leaf(root, c)
  if not leaf or not leaf.parent then return end

  local target_orientation = (direction == "left" or direction == "right") and tree.HORIZONTAL or tree.VERTICAL

  local current = leaf
  while current.parent do
    local parent = current.parent
    if parent.orientation == target_orientation then
      local delta = (direction == "right" or direction == "down") and amount or -amount
      parent.ratio = math.max(0.1, math.min(0.9, parent.ratio + delta))
      awful.layout.arrange(tag.screen)
      return
    end
    current = parent
  end
end

function master.swap_bydirection(direction, c)
  if not c then c = capi.client.focus end
  if not c then return end

  local tag = c.first_tag
  if not tag then return end

  local root = state.trees[tag]
  if not root then return end

  local leaf = tree.find_leaf(root, c)
  if not leaf then return end

  local bounds = state.bounds[tag]
  if not bounds then return end

  local src = nil
  for _, b in ipairs(bounds) do
    if b.leaf == leaf then
      src = b
      break
    end
  end
  if not src then return end

  local src_cx = src.x + src.w / 2
  local src_cy = src.y + src.h / 2

  local best_leaf = nil
  local best_dist = math.huge

  for _, b in ipairs(bounds) do
    if b.leaf ~= leaf and b.leaf.client then
      local tgt_cx = b.x + b.w / 2
      local tgt_cy = b.y + b.h / 2

      local dominated = false
      local dist = 0

      if direction == "left" and tgt_cx < src_cx then
        dominated = true
        dist = (src_cx - tgt_cx) + math.abs(tgt_cy - src_cy) * 0.3
      elseif direction == "right" and tgt_cx > src_cx then
        dominated = true
        dist = (tgt_cx - src_cx) + math.abs(tgt_cy - src_cy) * 0.3
      elseif direction == "up" and tgt_cy < src_cy then
        dominated = true
        dist = (src_cy - tgt_cy) + math.abs(tgt_cx - src_cx) * 0.3
      elseif direction == "down" and tgt_cy > src_cy then
        dominated = true
        dist = (tgt_cy - src_cy) + math.abs(tgt_cx - src_cx) * 0.3
      end

      if dominated and dist < best_dist then
        best_dist = dist
        best_leaf = b.leaf
      end
    end
  end

  if best_leaf then
    tree.swap_clients(leaf, best_leaf)
    awful.layout.arrange(tag.screen)
  end
end

function master.set_ratio(c, ratio)
  if not c then c = capi.client.focus end
  if not c then return end

  local tag = c.first_tag
  if not tag then return end

  local root = state.trees[tag]
  if not root then return end

  local leaf = tree.find_leaf(root, c)
  if not leaf or not leaf.parent then return end

  leaf.parent.ratio = math.max(0.1, math.min(0.9, ratio))
  awful.layout.arrange(tag.screen)
end

function master.rotate(c)
  if not c then c = capi.client.focus end
  if not c then return end

  local tag = c.first_tag
  if not tag then return end

  local root = state.trees[tag]
  if not root then return end

  local leaf = tree.find_leaf(root, c)
  if not leaf or not leaf.parent then return end

  local parent = leaf.parent
  parent.orientation = parent.orientation == tree.HORIZONTAL
      and tree.VERTICAL or tree.HORIZONTAL

  awful.layout.arrange(tag.screen)
end

function master.swap_with_first(c)
  if not c then c = capi.client.focus end
  if not c then return end

  local tag = c.first_tag
  if not tag then return end

  local root = state.trees[tag]
  if not root then return end

  local leaf = tree.find_leaf(root, c)
  if not leaf then return end

  local leaves = tree.collect_leaves(root)
  if #leaves < 2 then return end

  if leaves[1] ~= leaf then
    tree.swap_clients(leaf, leaves[1])
    awful.layout.arrange(tag.screen)
  end
end

capi.client.connect_signal("unmanage", function(c)
  for tag, root in pairs(state.trees) do
    local leaf = tree.find_leaf(root, c)
    if leaf then
      state.trees[tag] = tree.remove_leaf(root, leaf)
    end
  end
end)

return master
