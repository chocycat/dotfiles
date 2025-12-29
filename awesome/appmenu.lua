local appmenu = gears.object({})

local lgi = require("lgi")
local Gio = lgi.Gio
local GLib = lgi.GLib
local GObject = lgi.GObject

local registrations = {}
local services = {}
local subs = {}
local conn = nil

local DBUSMENU_INTERFACE = "com.canonical.dbusmenu"

local function unpack(variant)
  if variant == nil then return nil end
  if type(variant) ~= "userdata" then return variant end

  local success, result = pcall(function()
    local vtype = variant:get_type_string()

    if vtype == "v" then
      return unpack(variant:get_variant())
    elseif vtype == "s" or vtype == "o" then
      return variant:get_string()
    elseif vtype == "b" then
      return variant:get_boolean()
    elseif vtype == "i" then
      return variant:get_int32()
    elseif vtype == "u" then
      return variant:get_uint32()
    elseif vtype == "x" then
      return variant:get_int64()
    elseif vtype == "t" then
      return variant:get_uint64()
    elseif vtype == "d" then
      return variant:get_double()
    elseif vtype == "ay" then
      local bytes = {}
      local n = variant:n_children()
      for i = 0, n - 1 do
        bytes[#bytes + 1] = string.char(variant:get_child_value(i):get_byte())
      end
      return table.concat(bytes)
    elseif vtype:sub(1, 1) == "a" then
      local res = {}
      local n = variant:n_children()
      if vtype:sub(2, 2) == "{" then
        for i = 0, n - 1 do
          local entry = variant:get_child_value(i)
          local key = unpack(entry:get_child_value(0))
          local val = unpack(entry:get_child_value(1))
          if key then res[key] = val end
        end
      else
        for i = 0, n - 1 do
          res[i + 1] = unpack(variant:get_child_value(i))
        end
      end
      return res
    elseif vtype:sub(1, 1) == "(" then
      local res = {}
      local n = variant:n_children()
      for i = 0, n - 1 do
        res[i + 1] = unpack(variant:get_child_value(i))
      end
      return res
    else
      return tostring(variant)
    end
  end)

  if success then return result else return nil end
end

local function parse_menu_item(item_variant)
  if type(item_variant) ~= "userdata" then return nil end

  local success, item = pcall(function()
    local result = {}
    result.id = unpack(item_variant:get_child_value(0))
    result.properties = unpack(item_variant:get_child_value(1)) or {}
    result.children = {}

    local children_variant = item_variant:get_child_value(2)
    if children_variant then
      local n = children_variant:n_children()
      for i = 0, n - 1 do
        local child_wrapper = children_variant:get_child_value(i)
        if child_wrapper then
          local child_struct = child_wrapper:get_variant()
          if child_struct then
            local parsed = parse_menu_item(child_struct)
            if parsed then
              result.children[#result.children + 1] = parsed
            end
          end
        end
      end
    end

    return result
  end)

  return success and item or nil
end

local function fetch_layout(s, p, parent_id, depth, cb)
  parent_id = parent_id or 0
  depth = depth or -1

  GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
    conn:call(
      s,
      p,
      DBUSMENU_INTERFACE,
      "GetLayout",
      GLib.Variant("(iias)", { parent_id, depth, {} }),
      nil,
      Gio.DBusCallFlags.NONE,
      5000,
      nil,
      function(conn, result)
        local ok, reply_or_err = pcall(function()
          return conn:call_finish(result)
        end)

        if not ok or not reply_or_err then
          if cb then cb(nil, reply_or_err) end
          return
        end

        local reply = reply_or_err
        local revision = unpack(reply:get_child_value(0))
        local root_variant = reply:get_child_value(1)
        local root_item = parse_menu_item(root_variant)

        local layout = {
          revision = revision,
          root = root_item
        }

        if cb then cb(layout, nil) end
      end
    )
    return false
  end)
end

local function invoke(s, p, item_id, type, ts)
  type = type or "clicked"
  ts = ts or 0

  local data = GLib.Variant("v", GLib.Variant("s", ""))
  local params = GLib.Variant("(isvu)", { item_id, type, data, ts })

  conn:call(
    s,
    p,
    DBUSMENU_INTERFACE,
    "Event",
    params,
    nil,
    Gio.DBusCallFlags.NO_AUTO_START,
    1000,
    nil,
    function(conn, result)
      pcall(function() conn:call_finish(result) end)
    end
  )
end

local function about_to_show(s, p, item_id, cb)
  conn:call(
    s,
    p,
    DBUSMENU_INTERFACE,
    "AboutToShow",
    GLib.Variant("(i)", { item_id }),
    nil,
    Gio.DBusCallFlags.NONE,
    5000,
    nil,
    function(conn, result)
      local ok, reply = pcall(function()
        return conn:call_finish(result)
      end)

      if not ok or not reply then
        if cb then cb(false, reply) end
        return
      end

      local needs_update = unpack(reply:get_child_value(0))
      if cb then cb(needs_update, nil) end
    end
  )
end

local function on_vanished(s)
  local svc = services[s]
  if not svc then return end

  for wid, _ in pairs(svc.wids) do
    subs[wid] = nil
    registrations[wid] = nil

    pcall(function()
      conn:emit_signal(
        nil,
        "/com/canonical/AppMenu/Registrar",
        "com.canonical.AppMenu.Registrar",
        "WindowUnregistered",
        GLib.Variant("(u)", { wid })
      )
      appmenu:emit_signal("menu::update", wid)
    end)
  end

  if svc.watch_id then
    pcall(function()
      conn:signal_unsubscribe(svc.watch_id)
    end)
  end
  services[s] = nil
end

local function watch(s)
  if services[s] then return end

  services[s] = {
    wids = {},
    watch_id = nil
  }

  local sub_id = conn:signal_subscribe(
    "org.freedesktop.DBus",
    "org.freedesktop.DBus",
    "NameOwnerChanged",
    "/org/freedesktop/DBus",
    s,
    Gio.DBusSignalFlags.NONE,
    function(_, _, _, _, _, params)
      local name = unpack(params:get_child_value(0))
      local new_owner = unpack(params:get_child_value(2))

      if name == s and (new_owner == "" or new_owner == nil) then
        on_vanished(s)
      end
    end
  )

  services[s].watch_id = sub_id
end

local function unsubscribe(wid)
  local sub = subs[wid]
  if sub then
    pcall(function()
      if sub.layout_sub then conn:signal_unsubscribe(sub.layout_sub) end
      if sub.props_sub then conn:signal_unsubscribe(sub.props_sub) end
    end)
    subs[wid] = nil
  end
end

local function subscribe(wid, s, p)
  if subs[wid] then return end

  local layout_sub = conn:signal_subscribe(
    s,
    DBUSMENU_INTERFACE,
    "LayoutUpdated",
    p,
    nil,
    Gio.DBusSignalFlags.NONE,
    function()
      appmenu:emit_signal("menu::update", wid)
    end
  )

  local props_sub = conn:signal_subscribe(
    s,
    DBUSMENU_INTERFACE,
    "ItemsPropertiesUpdated",
    p,
    nil,
    Gio.DBusSignalFlags.NONE,
    function()
      appmenu:emit_signal("menu::update", wid)
    end
  )

  subs[wid] = {
    layout_sub = layout_sub,
    props_sub = props_sub
  }
end

local XML = [[
<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node>
  <interface name="com.canonical.AppMenu.Registrar">
    <method name="RegisterWindow">
      <arg type="u" name="windowId" direction="in"/>
      <arg type="o" name="menuObjectPath" direction="in"/>
    </method>
    <method name="UnregisterWindow">
      <arg type="u" name="windowId" direction="in"/>
    </method>
    <method name="GetMenuForWindow">
      <arg type="u" name="windowId" direction="in"/>
      <arg type="s" name="service" direction="out"/>
      <arg type="o" name="menuObjectPath" direction="out"/>
    </method>
    <method name="GetMenus">
      <arg type="a(uso)" name="menus" direction="out"/>
    </method>
    <signal name="WindowRegistered">
      <arg type="u" name="windowId"/>
      <arg type="s" name="service"/>
      <arg type="o" name="menuObjectPath"/>
    </signal>
    <signal name="WindowUnregistered">
      <arg type="u" name="windowId"/>
    </signal>
  </interface>
</node>
]]

local function handle_method(conn, sender, _, _, name, params, invocation)
  local ok, err = pcall(function()
    if name == "RegisterWindow" then
      local wid = params:get_child_value(0):get_uint32()
      local menu_path = params:get_child_value(1):get_string()

      registrations[wid] = {
        service = sender,
        path = menu_path
      }

      watch(sender)
      services[sender].wids[wid] = true

      pcall(function()
        conn:emit_signal(
          nil,
          "/com/canonical/AppMenu/Registrar",
          "com.canonical.AppMenu.Registrar",
          "WindowRegistered",
          GLib.Variant("(uso)", { wid, sender, menu_path })
        )
        appmenu:emit_signal("menu::update", wid)
      end)

      invocation:return_value(GLib.Variant.new_tuple({}))

      GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
        subscribe(wid, sender, menu_path)
        return false
      end)

      return
    elseif name == "UnregisterWindow" then
      local wid = params:get_child_value(0):get_uint32()

      local reg = registrations[wid]
      if reg then
        unsubscribe(wid)
        if services[reg.service] then
          services[reg.service].wids[wid] = nil
        end
        registrations[wid] = nil

        pcall(function()
          conn:emit_signal(
            nil,
            "/com/canonical/AppMenu/Registrar",
            "com.canonical.AppMenu.Registrar",
            "WindowUnregistered",
            GLib.Variant("(u)", { wid })
          )
          appmenu:emit_signal("menu::update", wid)
        end)
      end

      invocation:return_value(GLib.Variant.new_tuple({}))
    elseif name == "GetMenuForWindow" then
      local wid = params:get_child_value(0):get_uint32()
      local reg = registrations[wid]

      if reg then
        invocation:return_value(GLib.Variant("(so)", { reg.service, reg.path }))
      else
        invocation:return_dbus_error(
          "com.canonical.AppMenu.Registrar.WindowNotFound",
          "No menu registered for window " .. wid
        )
      end
    elseif name == "GetMenus" then
      local menus = {}
      for wid, reg in pairs(registrations) do
        menus[#menus + 1] = { wid, reg.service, reg.path }
      end
      invocation:return_value(GLib.Variant("(a(uso))", { menus }))
    else
      invocation:return_dbus_error(
        "org.freedesktop.DBus.Error.UnknownMethod",
        "Unknown method: " .. name
      )
    end
  end)

  if not ok then
    pcall(function()
      invocation:return_dbus_error(
        "com.canonical.AppMenu.Registrar.InternalError",
        "Internal error: " .. tostring(err)
      )
    end)
  end
end

local function handle_get_property()
  return nil
end

local function handle_set_property()
  return false
end

local function start_registrar(callback)
  Gio.bus_get(Gio.BusType.SESSION, nil, function(_, result)
    local ok, connection = pcall(function()
      return Gio.bus_get_finish(result)
    end)

    if not ok or not connection then
      if callback then callback(false) end
      return
    end

    conn = connection

    local node_info = Gio.DBusNodeInfo.new_for_xml(XML)
    if not node_info then
      if callback then callback(false) end
      return
    end

    local interface_info = node_info:lookup_interface("com.canonical.AppMenu.Registrar")
    if not interface_info then
      if callback then callback(false) end
      return
    end

    local reg_id = conn:register_object(
      "/com/canonical/AppMenu/Registrar",
      interface_info,
      GObject.Closure(handle_method),
      GObject.Closure(handle_get_property),
      GObject.Closure(handle_set_property)
    )

    if not reg_id or reg_id == 0 then
      if callback then callback(false) end
      return
    end

    conn:call(
      "org.freedesktop.DBus",
      "/org/freedesktop/DBus",
      "org.freedesktop.DBus",
      "RequestName",
      GLib.Variant("(su)", { "com.canonical.AppMenu.Registrar", 0 }),
      GLib.VariantType.new("(u)"),
      Gio.DBusCallFlags.NONE,
      -1,
      nil,
      function(connection, res)
        local success = pcall(function()
          return connection:call_finish(res)
        end)
        if callback then callback(success) end
      end
    )
  end)
end
local function convert_item(item, service, path)
  local props = item.properties or {}

  if props.visible == false then
    return nil
  end

  if props.type == "separator" then
    return { separator = true }
  end

  local result = {}
  local label = props.label or ""
  result.text = label:gsub("_", "")

  local toggle_type = props["toggle-type"]
  local toggle_state = props["toggle-state"]

  if toggle_type == "checkmark" then
    result.checked = (toggle_state == 1)
  elseif toggle_type == "radio" then
    result.radio = (toggle_state == 1)
  end

  local has_children = item.children and #item.children > 0
  local children_display = props["children-display"]

  if has_children or children_display == "submenu" then
    if has_children then
      result.submenu = {}
      for _, child in ipairs(item.children) do
        local converted = convert_item(child, service, path)
        if converted then
          table.insert(result.submenu, converted)
        end
      end
      if #result.submenu == 0 then
        result.submenu = nil
        local item_id = item.id
        result.on_click = function()
          about_to_show(service, path, item_id, function() end)
        end
      end
    else
      result.submenu = {}
      result._item_id = item.id
      result._service = service
      result._path = path
    end
  else
    local item_id = item.id
    result.on_click = function()
      invoke(service, path, item_id, "clicked", 0)
    end
  end

  return result
end

function appmenu.create_bar(wid, cb)
  local reg = registrations[wid]
  if not reg then
    cb(nil)
    return
  end

  fetch_layout(reg.service, reg.path, 0, -1, function(layout)
    if not layout or not layout.root or not layout.root.children then
      cb(nil)
      return
    end

    local menus = {}

    for _, top_item in ipairs(layout.root.children) do
      local props = top_item.properties or {}

      if props.visible ~= false then
        local label = props.label or ""
        local title = label:gsub("_", "")

        local items = {}
        if top_item.children then
          for _, child in ipairs(top_item.children) do
            local converted = convert_item(child, reg.service, reg.path)
            local prev_is_separator = false
            if #items > 0 and items[#items].separator then
              prev_is_separator = true
            end

            if converted then
              if (converted.separator and prev_is_separator) or
                  (converted.submenu and #converted.submenu == 0) then
                -- skip
              else
                table.insert(items, converted)
              end
            end
          end
        end

        if title ~= "" then
          table.insert(menus, {
            title = title,
            items = items,
            _item_id = top_item.id,
            _service = reg.service,
            _path = reg.path,
          })
        end
      end
    end

    cb(menus, reg.service, reg.path)
  end)
end

start_registrar(function(_) end)

return appmenu
