function sortedModes(monitor) {
    const currentResolution = monitor.width + "x" + monitor.height;
    return (monitor.availableModes || []).slice().sort((left, right) => {
        const leftParts = left.match(/^(\d+)x(\d+)@([\d.]+)/);
        const rightParts = right.match(/^(\d+)x(\d+)@([\d.]+)/);
        if (!leftParts || !rightParts) return left.localeCompare(right);
        const leftCurrent = left.startsWith(currentResolution + "@");
        const rightCurrent = right.startsWith(currentResolution + "@");
        return Number(rightCurrent) - Number(leftCurrent)
            || Number(rightParts[1]) * Number(rightParts[2]) - Number(leftParts[1]) * Number(leftParts[2])
            || Number(rightParts[3]) - Number(leftParts[3]);
    });
}

function arrangementCommand(monitors, positions, usingLua) {
    if (!Array.isArray(positions) || !positions.length) return [];
    const names = new Set();
    const commands = [];
    for (const position of positions) {
        if (!position || names.has(position.name) || !Number.isInteger(position.x) || !Number.isInteger(position.y)
                || Math.abs(position.x) > 32768 || Math.abs(position.y) > 32768) return [];
        const monitor = monitors.find(entry => entry.name === position.name && !entry.disabled);
        if (!monitor) return [];
        names.add(position.name);
        const updated = Object.assign({}, monitor, {x:position.x,y:position.y});
        const change = command(updated, monitor.width + "x" + monitor.height + "@" + monitor.refreshRate, monitor.scale, monitor.transform, usingLua);
        if (!change.length) return [];
        commands.push(usingLua ? change[2] : change.slice(1).join(" "));
    }
    return ["hyprctl", usingLua ? "repl" : "--batch", commands.join("; ")];
}

function command(monitor, mode, scale, transform, usingLua) {
    if (!monitor || !/^[A-Za-z0-9_.:-]+$/.test(monitor.name)
            || !/^\d+x\d+@\d+(?:\.\d+)?(?:Hz)?$/.test(mode)
            || !Number.isInteger(monitor.x) || !Number.isInteger(monitor.y)
            || !Number.isFinite(scale) || scale < 0.5 || scale > 3
            || !Number.isInteger(transform) || transform < 0 || transform > 7) return [];
    const position = monitor.x + "x" + monitor.y;
    if (usingLua) {
        return ["hyprctl", "repl", "hl.monitor({output=" + JSON.stringify(monitor.name)
            + ",mode=" + JSON.stringify(mode.replace(/Hz$/, ""))
            + ",position=" + JSON.stringify(position)
            + ",scale=" + scale + ",transform=" + transform + "})"];
    }
    return ["hyprctl", "keyword", "monitor", monitor.name + "," + mode + "," + position + "," + scale + ",transform," + transform];
}