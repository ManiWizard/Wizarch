-- Run from the repository: lua tests/scrolling-peeks.lua
-- Exercises the installed example's native Lua callbacks with workspace objects.
local callbacks, timers, commands = {}, {}, {}
local workspace = { id = 1, tiled_layout = 'scrolling' }
local other = { id = 2, tiled_layout = 'scrolling' }
local active, windows
local dspMock = {__index = function() return function(value) return value end end}
hl = {
    config = function() end,
    get_active_window = function() return active end,
    get_active_workspace = function() return workspace end,
    get_windows = function(filters)
        local found = {}
        for _, w in ipairs(windows) do
            if w.workspace == filters.workspace and not w.floating then found[#found + 1] = w end
        end
        return found
    end,
    on = function(event, fn) callbacks[event] = fn end,
    timer = function(fn, options) timers[#timers + 1] = {fn = fn, options = options} end,
    bind = function() end,
    dsp = setmetatable({window = setmetatable({}, dspMock), workspace = setmetatable({}, dspMock), cursor = setmetatable({}, dspMock)}, dspMock),
    dispatch = function(command)
        commands[#commands + 1] = command
        local width = type(command) == 'string' and command:match('^colresize all (.+)$')
        if width then
            for _, w in ipairs(windows) do
                if w.workspace == active.workspace and w.layout and w.layout.column then
                    w.layout.column.width = tonumber(width)
                end
            end
        end
    end,
}
local identity = 0
local function win(index, ws, width)
    identity = identity + 1
    return {address = 'window-' .. identity, mapped = true, workspace = ws or workspace,
        layout = {name = 'scrolling', column = {index = index, width = width or 1}}}
end
active = win(0)
windows = {active}
-- Keep the module's optional persisted-layout import isolated from user files.
local realOpen = io.open
io.open = function() return nil end
assert(loadfile('examples/wizarch-windows.lua'))()
io.open = realOpen
local poll = timers[1].fn
local function reset() commands = {} end
local function changed(width)
    assert(#commands == 2 and commands[1] == 'colresize all ' .. width and commands[2] == 'center', table.concat(commands, ', '))
end
-- A lone column uses full width, including vertically stacked windows.
active.layout.column.width = .96
poll(); changed(1.0)
windows[#windows + 1] = win(0, workspace, .96)
reset(); poll(); changed(1.0)
-- Count real columns, regardless of index gaps or number of windows.
windows[#windows + 1] = win(3)
reset(); poll(); changed(.96)
reset(); poll(); assert(#commands == 0, 'settled state must not repeatedly dispatch')
active.layout.column.width = .8
reset(); poll(); assert(#commands == 0, 'manual column resizing must survive the fallback')
-- An unrelated workspace, hidden or floating/pinned clients add no columns.
windows = {active, win(8, other), win(4), win(5), win(6)}
windows[3].hidden = true; windows[4].floating = true; windows[5].pinned = true
reset(); poll(); changed(1.0)
for _, flag in ipairs({'floating', 'hidden', 'pinned'}) do
    active[flag] = true; reset(); poll(); assert(#commands == 0); active[flag] = false
end
active.mapped = false; reset(); poll(); assert(#commands == 0); active.mapped = true
for _, flag in ipairs({'special', 'has_fullscreen'}) do
    workspace[flag] = true; reset(); poll(); assert(#commands == 0); workspace[flag] = false
end
workspace.tiled_layout = 'dwindle'; reset(); poll(); assert(#commands == 0)
workspace.tiled_layout = 'scrolling'
-- The initial pending update coalesces events and observes fresh focus.
local before = #timers
callbacks['window.open'](); callbacks['window.close'](); assert(#timers == before)
active = nil; timers[2].fn(); assert(#commands == 0)
active = win(0, other, .96); windows = {active}
callbacks['window.active'](); assert(#timers == before + 1)
reset(); timers[#timers].fn(); changed(1.0)
-- Layout switches without focus events are reconciled by the fallback.
windows[#windows + 1] = win(1, other)
reset(); poll(); changed(.96)
print('PASS: distinct columns, lifecycle reconciliation, exclusions, workspace isolation, deferred current focus, idle dispatch suppression')
