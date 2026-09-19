pragma Singleton
import QtQuick

QtObject {
    property var palette: ({paper: "#efefeb", ink: "#1c1c1c", muted: "#aaaaaa", line: "#525252", hover: "#353535", stage: "#d4d4d4", accent: "#efefeb"})
    function controlBorderWidth(item) {
        let scale = 1;
        while (item) {
            scale *= item.scale;
            item = item.parent;
        }
        return Math.max(2, Math.ceil(1 / Math.max(0.01, Math.abs(scale))));
    }
    readonly property color paper: palette.paper
    readonly property color ink: palette.ink
    readonly property color muted: palette.muted
    readonly property color line: palette.line
    readonly property color hover: palette.hover
    readonly property color stage: palette.stage
    readonly property color accent: palette.accent
    readonly property color chartPrimary: Qt.rgba((paper.r + accent.r) / 2, (paper.g + accent.g) / 2, (paper.b + accent.b) / 2, 1)
    function chartColor(index) {
        const lightSurface = 0.2126 * ink.r + 0.7152 * ink.g + 0.0722 * ink.b > 0.5;
        const colors = lightSurface
            ? ["#006eaa", "#a55b00", "#187345", "#a53570"]
            : ["#56c8ff", "#f2c45e", "#7ed9a3", "#ef8fbf"];
        return colors[index % colors.length];
    }
    readonly property color groupSurface: Qt.lighter(ink, 1.5)
    property bool glassEnabled: true
    property bool floatingPanels: false
    property int panelRadius: 8
    property int barRadius: 8
    property int windowRadius: 8
    property string animationStyle: "Stepped"
    function animatedProgress(value) {
        return animationStyle === "Stepped" ? Math.floor(value * 6) / 6 : value;
    }
    property int animationDuration: 240
    property int panelOpacity: 84
    property int windowOpacity: 92
    readonly property color surface: glassEnabled ? Qt.rgba(ink.r, ink.g, ink.b, panelOpacity / 100) : ink
    readonly property color windowSurface: glassEnabled ? Qt.rgba(ink.r, ink.g, ink.b, windowOpacity / 100) : ink
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.22)
    readonly property color surfaceEdge: Qt.lighter(line, 1.4)
    readonly property color selection: Qt.rgba(accent.r, accent.g, accent.b, 0.12)
    readonly property color clear: "transparent"
    readonly property int radius: 6
    readonly property int barHeight: 48
    readonly property int motion: 120
    readonly property string displayFont: displayLoader.name
    readonly property string textFont: textLoader.name
    readonly property bool fontsReady: displayLoader.status === FontLoader.Ready && textLoader.status === FontLoader.Ready
    property FontLoader displayLoader: FontLoader { source: "../Assets/Fonts/Monocraft.ttf" }
    property FontLoader textLoader: FontLoader { source: "../Assets/Fonts/JetBrainsMono.ttf" }
}