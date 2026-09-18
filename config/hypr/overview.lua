local overview = 'bash "' .. os.getenv("HOME") .. '/repositories/quickshell/tools/overview.sh"'

hl.on("hyprland.start", function()
    hl.exec_cmd(overview .. " start")
end)
hl.bind("SUPER + TAB", hl.dsp.exec_cmd(overview .. " toggle"))