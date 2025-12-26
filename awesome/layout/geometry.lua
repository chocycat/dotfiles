local tree = require("layout.tree")

local geometry = {}

local function is_skip_leaf(node, skip_client)
  if not skip_client or not node then return false end
  return node.type == tree.LEAF and node.client == skip_client
end

function geometry.get_min_size(node, gap, skip_client)
  if not node then return 1, 1 end

  if node.type == tree.LEAF then
    if skip_client and node.client == skip_client then
      return 0, 0
    end
    local c = node.client
    if c and c.size_hints then
      return c.size_hints.min_width or 1, c.size_hints.min_height or 1
    end
    return 1, 1
  end

  local first_is_skip = is_skip_leaf(node.first, skip_client)
  local second_is_skip = is_skip_leaf(node.second, skip_client)

  if first_is_skip then
    return geometry.get_min_size(node.second, gap, skip_client)
  elseif second_is_skip then
    return geometry.get_min_size(node.first, gap, skip_client)
  end

  local fw, fh = geometry.get_min_size(node.first, gap, skip_client)
  local sw, sh = geometry.get_min_size(node.second, gap, skip_client)

  if node.orientation == tree.HORIZONTAL then
    return fw + sw + gap, math.max(fh, sh)
  else
    return math.max(fw, sw), fh + sh + gap
  end
end

function geometry.clamp_ratio(node, available, gap, skip_client)
  local ratio = node.ratio
  local first_min_w, first_min_h = geometry.get_min_size(node.first, gap, skip_client)
  local second_min_w, second_min_h = geometry.get_min_size(node.second, gap, skip_client)

  local usable, first_min, second_min
  if node.orientation == tree.HORIZONTAL then
    usable = available.w - gap
    first_min, second_min = first_min_w, second_min_w
  else
    usable = available.h - gap
    first_min, second_min = first_min_h, second_min_h
  end

  if usable <= 0 then return ratio end

  local first_size = usable * ratio
  local second_size = usable * (1 - ratio)

  if first_size < first_min then
    ratio = first_min / usable
  elseif second_size < second_min then
    ratio = (usable - second_min) / usable
  end

  return math.max(0.05, math.min(0.95, ratio))
end

function geometry.calculate(node, x, y, w, h, gap, results, skip_client)
  results = results or {}
  if not node then return results end

  if node.type == tree.LEAF then
    if skip_client and node.client == skip_client then
      -- don't generate bounds for the dragged window
      return results
    end
    table.insert(results, { leaf = node, x = x, y = y, w = w, h = h })
    return results
  end

  local first_is_skip = is_skip_leaf(node.first, skip_client)
  local second_is_skip = is_skip_leaf(node.second, skip_client)

  if first_is_skip then
    -- skip the first child entirely, give all space to second
    geometry.calculate(node.second, x, y, w, h, gap, results, skip_client)
  elseif second_is_skip then
    -- skip the second child entirely, give all space to first
    geometry.calculate(node.first, x, y, w, h, gap, results, skip_client)
  else
    -- normal split behavior
    local ratio = geometry.clamp_ratio(node, { w = w, h = h }, gap, skip_client)

    if node.orientation == tree.HORIZONTAL then
      local first_w = math.floor((w - gap) * ratio)
      local second_w = w - gap - first_w
      geometry.calculate(node.first, x, y, first_w, h, gap, results, skip_client)
      geometry.calculate(node.second, x + first_w + gap, y, second_w, h, gap, results, skip_client)
    else
      local first_h = math.floor((h - gap) * ratio)
      local second_h = h - gap - first_h
      geometry.calculate(node.first, x, y, w, first_h, gap, results, skip_client)
      geometry.calculate(node.second, x, y + first_h + gap, w, second_h, gap, results, skip_client)
    end
  end

  return results
end

return geometry
