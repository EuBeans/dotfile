function command(key, value) {
    if (key === "focusBorderColor") {
        if (typeof value !== "string" || !/^#[0-9a-f]{6}$/i.test(value)) return "";
        return 'hl.config({general={col={active_border="rgba(' + value.slice(1) + 'ff)"}}})';
    }
    if (key === "windowOpacity") {
        if (!Number.isInteger(value) || value < 40 || value > 100) return "";
        return "hl.config({decoration={active_opacity=" + value / 100 + ",inactive_opacity=" + value / 100 + "}})";
    }
    if (key === "tilingLayout") {
        const layouts = {
            Split: 'hl.config({general={layout="dwindle"}})',
            Columns: 'hl.config({general={layout="master"},master={orientation="left"}})',
            Centered: 'hl.config({general={layout="master"},master={orientation="center"}})'
        };
        return layouts[value] || "";
    }
    const fields = {
        tileGap: {section: "general", name: "gaps_in", min: 0, max: 32},
        outerGap: {section: "general", name: "gaps_out", min: 0, max: 64},
        windowBorderWidth: {section: "general", name: "border_size", min: 0, max: 8},
        windowRadius: {section: "decoration", name: "rounding", min: 0, max: 24},
        mainPaneRatio: {section: "master", name: "mfact", min: 30, max: 70}
    };
    const field = fields[key];
    if (!field || !Number.isInteger(value) || value < field.min || value > field.max) return "";
    const setting = key === "mainPaneRatio" ? value / 100 : value;
    return "hl.config({" + field.section + "={" + field.name + "=" + setting + "}})";
}