-- Native Qt apps follow GTK desktop mode; requires the Qt gtk3 platform plugin.
-- Keep your explicit QT_QPA_PLATFORMTHEME instead if using KDE/qt6ct.
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

-- Load this from the end of your existing ~/.config/hypr/hyprland.lua.
-- Initialize Wizarch first so wizarch-theme.lua exists.
dofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/wizarch-theme.lua")
-- Load the spacing saved by Quickshell settings, when available.
do
    local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    local spacing = config_home .. "/hypr/wizarch-spacing.lua"
    local file = io.open(spacing, "r")
    if file then file:close(); dofile(spacing) end
end


hl.on("hyprland.start", function()
    hl.exec_cmd("qs --no-duplicate --daemonize")
    hl.exec_cmd("wl-paste --watch cliphist store")
end)

-- Restore each monitor's nine independent workspace slots, when initialized.
do
    local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    local workspaces = config_home .. "/hypr/wizarch-workspaces.lua"
    local file = io.open(workspaces, "r")
    if file then file:close(); dofile(workspaces) end
end

local open = "$HOME/.local/bin/wizarch-open "
hl.bind("SUPER + SPACE",   hl.dsp.exec_cmd(open .. "launcher"))
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd(open .. "clock"))
hl.bind("SUPER + ALT + Q", hl.dsp.exec_cmd(open .. "status"))
hl.bind("SUPER + ALT + N", hl.dsp.exec_cmd(open .. "notifications"))
hl.bind("SUPER + ALT + T", hl.dsp.exec_cmd(open .. "themes"))
hl.bind("SUPER + L", hl.dsp.exec_cmd("hyprlock --config $HOME/.config/hypr/hyprlock.conf"))
hl.bind("SUPER + V", hl.dsp.exec_cmd(open .. "clipboard"))
hl.bind("SUPER + PERIOD", hl.dsp.exec_cmd(open .. "emoji"))

for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.exec_cmd("python3 $HOME/.config/quickshell/services/workspaces.py switch " .. i))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.exec_cmd("python3 $HOME/.config/quickshell/services/workspaces.py move " .. i))
end
hl.bind("SUPER + mouse_down", hl.dsp.exec_cmd("python3 $HOME/.config/quickshell/services/workspaces.py switch next"))
hl.bind("SUPER + mouse_up",   hl.dsp.exec_cmd("python3 $HOME/.config/quickshell/services/workspaces.py switch prev"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("$HOME/.local/bin/hypr-desktop"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("$HOME/.local/bin/hypr-screenshot"))

hl.window_rule({
    name = "wizarch-settings",
    match = { class = "org.quickshell", title = "Wizarch Settings" },
    -- Settings is a normal managed application window.
    float = false,
})

-- Individual-window controls, including reversible minimize and floating pin.
dofile(os.getenv("HOME") .. "/.config/hypr/wizarch-windows.lua")
