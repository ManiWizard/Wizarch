-- Load this from the end of your existing ~/.config/hypr/hyprland.lua.
-- Initialize Wizarch first so wizarch-theme.lua exists.
dofile(os.getenv("HOME") .. "/.config/hypr/wizarch-theme.lua")

hl.on("hyprland.start", function()
    hl.exec_cmd("qs --no-duplicate --daemonize")
end)

local open = "$HOME/.local/bin/wizarch-open "
hl.bind("SUPER + SPACE",   hl.dsp.exec_cmd(open .. "launcher"))
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd(open .. "clock"))
hl.bind("SUPER + ALT + Q", hl.dsp.exec_cmd(open .. "status"))
hl.bind("SUPER + ALT + N", hl.dsp.exec_cmd(open .. "notifications"))
hl.bind("SUPER + ALT + T", hl.dsp.exec_cmd(open .. "themes"))

for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.exec_cmd("python3 $HOME/.config/quickshell/services/workspaces.py switch " .. i))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.exec_cmd("python3 $HOME/.config/quickshell/services/workspaces.py move " .. i))
end
hl.bind("SUPER + mouse_down", hl.dsp.exec_cmd("python3 $HOME/.config/quickshell/services/workspaces.py switch next"))
hl.bind("SUPER + mouse_up",   hl.dsp.exec_cmd("python3 $HOME/.config/quickshell/services/workspaces.py switch prev"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("$HOME/.local/bin/hypr-desktop"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("$HOME/.local/bin/hypr-screenshot"))
