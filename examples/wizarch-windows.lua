-- Individual-window controls for Wizarch (Hyprland 0.56 Lua API).
local helper = 'python3 "$HOME/.config/quickshell/services/windows.py" '
local layout_helper = 'python3 "$HOME/.config/quickshell/services/layouts.py" toggle '
-- Native side peeks: one full-size column, or large 96% columns centered
-- around focus. The remaining 2% on each side shows the actual adjacent app.
hl.config({ scrolling = { column_width = 0.96, fullscreen_on_one_column = true,
    follow_focus = true, focus_fit_method = 0, wrap_focus = true } })

-- Use column identities, not window counts (stacked/grouped windows can share
-- a column). Dispatch only on the focused normal Scrolling workspace; never
-- focus an inactive monitor/workspace just to reconcile its geometry.
local peek_topology = {}
local function update_scrolling_peeks()
    local window = hl.get_active_window()
    if not window then return end
    local workspace = window.workspace
    if not workspace then return end
    if not window.mapped or window.hidden or window.floating or window.pinned
        or workspace.special or workspace.has_fullscreen or workspace.tiled_layout ~= "scrolling" then
        peek_topology[workspace.id] = nil
        return
    end
    local columns, members, count = {}, {}, 0
    for _, candidate in ipairs(hl.get_windows({ workspace = workspace, floating = false })) do
        local layout = candidate.layout
        if candidate.mapped and not candidate.hidden and not candidate.pinned
            and candidate.workspace and candidate.workspace.id == workspace.id
            and layout and layout.name == "scrolling" and layout.column then
            local column = layout.column
            if columns[column.index] == nil then count = count + 1 end
            columns[column.index] = column.width
            members[#members + 1] = tostring(column.index) .. ":" .. candidate.address
        end
    end
    if count == 0 then return end
    table.sort(members)
    local topology = table.concat(members, ";")
    if peek_topology[workspace.id] == topology then return end
    peek_topology[workspace.id] = topology
    -- Reconcile on topology/layout changes. Ordinary focus and the fallback do
    -- not overwrite a column the user has manually resized with existing keys.
    local width = count == 1 and 1.0 or 0.96
    for _, current in pairs(columns) do
        if math.abs(current - width) > 0.0001 then
            hl.dispatch(hl.dsp.layout("colresize all " .. width))
            hl.dispatch(hl.dsp.layout("center"))
            return
        end
    end
end
-- Defer until open/close/move and layout bookkeeping has settled. Read current
-- focus when the callback runs rather than retaining an event's stale window.
local peek_update_pending = false
local function schedule_scrolling_peeks()
    if peek_update_pending then return end
    peek_update_pending = true
    hl.timer(function()
        peek_update_pending = false
        update_scrolling_peeks()
    end, { timeout = 16, type = "oneshot" })
end
for _, event in ipairs({ "window.open", "window.close", "window.destroy", "window.active",
    "window.move_to_workspace", "window.fullscreen", "window.pin", "workspace.active",
    "workspace.special_active", "workspace.move_to_monitor", "config.reloaded" }) do
    hl.on(event, schedule_scrolling_peeks)
end
-- Layout toggles and column merges do not always emit a focus event. This cheap
-- fallback reads native Lua objects and makes no changes while topology is stable.
hl.timer(update_scrolling_peeks, { timeout = 500, type = "repeat" })
schedule_scrolling_peeks()
do
    local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    local layouts = config_home .. "/hypr/wizarch-layouts.lua"
    local file = io.open(layouts, "r")
    if file then file:close(); dofile(layouts) end
end
local function scrolling()
    local workspace = hl.get_active_workspace()
    return workspace and workspace.tiled_layout == "scrolling"
end
local function focus_direction(direction)
    return function()
        if scrolling() and (direction == "l" or direction == "r") then
            hl.dispatch(hl.dsp.layout("focus " .. direction))
        else
            hl.dispatch(hl.dsp.focus({ direction = direction }))
        end
    end
end
local function swap_direction(direction)
    return function()
        if scrolling() and (direction == "l" or direction == "r") then
            hl.dispatch(hl.dsp.layout("swapcol " .. direction))
        else
            hl.dispatch(hl.dsp.window.swap({ direction = direction }))
        end
    end
end
local function move_to_monitor(direction)
    return function()
        local window = hl.get_active_window()
        local monitor = hl.get_monitor(direction)
        if window and monitor and window.monitor and monitor.id ~= window.monitor.id then
            hl.dispatch(hl.dsp.window.move({ window = window, monitor = monitor, follow = true }))
        end
    end
end
local function selected_window(action)
    return function()
        local window = hl.get_active_window()
        if window then
            -- Capture and shell-quote the target before spawning the asynchronous worker.
            local addr = "'" .. tostring(window.address):gsub("'", "'\\''") .. "'"
            hl.dispatch(hl.dsp.exec_cmd(helper .. action .. " " .. addr))
        end
    end
end
local function bind(keys, description, action, options)
    options = options or {}
    options.description = description
    hl.bind(keys, action, options)
end

for _, direction in ipairs({ "LEFT", "RIGHT", "UP", "DOWN" }) do
    local short = direction:sub(1, 1):lower()
    bind("SUPER + " .. direction, "Focus window " .. direction:lower(), focus_direction(short))
    bind("SUPER + SHIFT + " .. direction, "Move window to monitor " .. direction:lower(),
        move_to_monitor(short))
    bind("SUPER + CTRL + SHIFT + " .. direction, "Move window to monitor " .. direction:lower(),
        move_to_monitor(short))
end

bind("SUPER + CTRL + L", "Toggle Dwindle/Scrolling on this workspace", function()
    local workspace = hl.get_active_workspace()
    if workspace then
        -- Shell-quote the captured selector; names can contain spaces or quotes.
        local raw = workspace.name
        local target = (raw and raw ~= "" and not raw:match("^%d+$")) and ("name:" .. raw) or tostring(workspace.id)
        local selector = "'" .. target:gsub("'", "'\\''") .. "'"
        hl.dispatch(hl.dsp.exec_cmd(layout_helper .. selector))
    end
end)

bind("SUPER + J", "Toggle horizontal/vertical split", hl.dsp.layout("togglesplit"))
bind("SUPER + T", "Toggle floating/tiling", hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + SHIFT + V", "Toggle floating/tiling", hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + F", "Toggle fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
bind("SUPER + ALT + F", "Toggle maximized", hl.dsp.window.fullscreen({ mode = "maximized" }))
bind("SUPER + O", "Toggle floating window on all workspaces", selected_window("pop"))
bind("SUPER + M", "Minimize window to tray", selected_window("minimize"))
bind("SUPER + SHIFT + M", "Restore last minimized window here", hl.dsp.exec_cmd(helper .. "restore"))
bind("SUPER + W", "Open shell quick-action wheel", hl.dsp.exec_cmd('python3 "$HOME/.config/quickshell/services/quick-wheel.py" toggle'))
bind("SUPER + C", "Close window (existing shortcut)", hl.dsp.window.close())

for _, reverse in ipairs({ false, true }) do
    bind(reverse and "ALT + SHIFT + TAB" or "ALT + TAB", reverse and "Previous window" or "Next window", function()
        hl.dispatch(hl.dsp.window.cycle_next({ next = not reverse }))
        hl.dispatch(hl.dsp.window.bring_to_top())
    end)
end

-- Named keys avoid the 0.56 keycode/NoSymbol issue and expose readable bindings.
for _, step in ipairs({ { "", 100 }, { " + ALT", 25 }, { " + CTRL", 300 } }) do
    for _, vertical in ipairs({ false, true }) do
        for _, sign in ipairs({ -1, 1 }) do
            local amount = step[2] * sign
            bind("SUPER" .. step[1] .. (vertical and " + SHIFT" or "") .. " + " .. (sign == -1 and "minus" or "equal"),
                (sign == -1 and "Shrink " or "Grow ") .. (vertical and "height " or "width ") .. step[2] .. " px",
                hl.dsp.window.resize({ x = vertical and 0 or amount, y = vertical and amount or 0, relative = true }),
                { repeating = true })
        end
    end
end

bind("SUPER + mouse:272", "Move window by dragging", hl.dsp.window.drag(), { mouse = true })
bind("SUPER + mouse:273", "Resize window by dragging", hl.dsp.window.resize(), { mouse = true })

-- Preserve the original tray shortcuts as aliases.
bind("SUPER + CTRL + ALT + LEFT", "Swap window left (existing shortcut)", swap_direction("l"))
bind("SUPER + CTRL + ALT + RIGHT", "Swap window right (existing shortcut)", swap_direction("r"))
bind("SUPER + CTRL + ALT + DOWN", "Minimize window to tray (existing shortcut)", selected_window("minimize"))
bind("SUPER + CTRL + ALT + UP", "Show/hide all tray windows", hl.dsp.workspace.toggle_special("wizarch-tray"))
