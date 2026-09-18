import QtQuick

Item {
    id: sampler
    required property url source
    property bool extractionEnabled: false
    property var palette: null
    property string status: "Saved theme"
    signal generationRequested(string imageSource)
    visible: false
    function refresh() {
        palette = null;
        status = extractionEnabled ? "Generating wallpaper colors" : "Saved theme";
        if (extractionEnabled) generationRequested(String(source));
    }
    function acceptResult(imageSource, colors, message) {
        if (!extractionEnabled || imageSource !== String(source)) return;
        const valid = colors && ["paper","ink","muted","line","hover","stage","accent"].every(key => /^#[0-9a-f]{6}$/i.test(colors[key] || ""));
        palette = valid ? colors : null;
        status = message;
    }
    onSourceChanged: refresh()
    onExtractionEnabledChanged: refresh()
}