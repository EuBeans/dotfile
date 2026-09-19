function restoreWorkspace(name) {
    const match = /^special:quickshell-minimized-([1-9][0-9]*)$/.exec(name || "");
    return match && Number.isSafeInteger(Number(match[1])) ? Number(match[1]) : 0;
}

function command(operation, window) {
    if (!window || !/^0x[0-9a-f]+$/i.test(window.address || "")) return "";
    const address = "address:" + window.address;
    if (operation === "minimize") {
        if (!Number.isSafeInteger(window.workspace) || window.workspace <= 0 || window.pinned) return "";
        return 'hl.dispatch(hl.dsp.window.move({workspace="special:quickshell-minimized-' + window.workspace + '",follow=false,window="' + address + '"}))';
    }
    if (operation === "restore") {
        const workspace = restoreWorkspace(window.workspaceName);
        if (!workspace) return "";
        return 'hl.dispatch(hl.dsp.window.move({workspace="' + workspace + '",follow=true,window="' + address + '"}))';
    }
    return "";
}