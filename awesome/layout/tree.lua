local tree = {}

tree.SPLIT = "split"
tree.LEAF = "leaf"
tree.HORIZONTAL = "horizontal"
tree.VERTICAL = "vertical"

function tree.new_leaf(client)
  return {
    type = tree.LEAF,
    client = client,
    parent = nil
  }
end

function tree.new_split(orientation, ratio, first, second)
  local node = {
    type = tree.SPLIT,
    orientation = orientation,
    ratio = ratio or 0.5,
    first = first,
    second = second,
    parent = nil
  }
  if first then first.parent = node end
  if second then second.parent = node end
  return node
end

function tree.find_leaf(node, client)
  if not node then return nil end
  if node.type == tree.LEAF then
    return node.client == client and node or nil
  end
  return tree.find_leaf(node.first, client) or tree.find_leaf(node.second, client)
end

function tree.find_leaf_at_point(bounds_list, x, y)
  for _, b in ipairs(bounds_list) do
    if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
      return b.leaf, b
    end
  end
  return nil, nil
end

function tree.find_closest_leaf(bounds_list, x, y)
  local closest, closest_bounds = nil, nil
  local closest_dist = math.huge
  for _, b in ipairs(bounds_list) do
    local cx, cy = b.x + b.w / 2, b.y + b.h / 2
    local dist = (cx - x) ^ 2 + (cy - y) ^ 2
    if dist < closest_dist then
      closest_dist = dist
      closest = b.leaf
      closest_bounds = b
    end
  end
  return closest, closest_bounds
end

function tree.insert_at_leaf(root, leaf, new_client, orientation, position)
  position = position or "second"

  local original_parent = leaf.parent
  local new_leaf = tree.new_leaf(new_client)

  local split
  if position == "first" then
    split = tree.new_split(orientation, 0.5, new_leaf, leaf)
  else
    split = tree.new_split(orientation, 0.5, leaf, new_leaf)
  end

  if not original_parent then
    return split
  end

  if original_parent.first == leaf then
    original_parent.first = split
  else
    original_parent.second = split
  end
  split.parent = original_parent

  return root
end

function tree.remove_leaf(root, leaf)
  local parent = leaf.parent
  if not parent then
    -- leaf is the root, tree becomes empty
    return nil
  end

  local sibling = parent.first == leaf and parent.second or parent.first
  local grandparent = parent.parent

  if not grandparent then
    -- parent was root, sibling becomes new root
    sibling.parent = nil
    return sibling
  end

  if grandparent.first == parent then
    grandparent.first = sibling
  else
    grandparent.second = sibling
  end
  sibling.parent = grandparent

  return root
end

function tree.swap_clients(leaf_a, leaf_b)
  leaf_a.client, leaf_b.client = leaf_b.client, leaf_a.client
end

function tree.collect_leaves(node, result)
  result = result or {}
  if not node then return result end
  if node.type == tree.LEAF then
    table.insert(result, node)
  else
    tree.collect_leaves(node.first, result)
    tree.collect_leaves(node.second, result)
  end
  return result
end

return tree
