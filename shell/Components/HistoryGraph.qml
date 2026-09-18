import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

ColumnLayout {
    id: graph
    required property string title
    property var series: []
    readonly property var lineColors: series.map((entry, index) => Theme.chartColor(index))
    readonly property bool current: series.some(entry => entry.current)
    readonly property string reading: current ? series.map(entry => entry.title + ": " + entry.reading).join(", ") : "Unavailable"
    function lineColor(index) {
        return lineColors[index];
    }
    function lineDash(index) {
        return [[], [6, 3], [2, 3], [8, 3, 2, 3], [12, 4], [6, 3, 2, 3], [2, 5], [12, 3, 2, 3]][index % 8];
    }
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    spacing: 8
    RowLayout {
        Layout.fillWidth: true
        Label { text: graph.title; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.family: Theme.displayFont; font.pixelSize: 14 }
        Label { text: graph.current ? "Live" : "Unavailable"; color: Theme.muted; font.pixelSize: 10 }
    }
    Canvas {
        id: plot
        objectName: graph.objectName + "Plot"
        Layout.fillWidth: true
        Layout.preferredHeight: 104
        Accessible.name: graph.title + ", " + (graph.current ? graph.reading : "unavailable")
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.strokeStyle = Theme.line;
            context.lineWidth = 1;
            for (let line = 0; line <= 2; line++) {
                const position = 1 + line * (height - 2) / 2;
                context.beginPath(); context.moveTo(0, position); context.lineTo(width, position); context.stroke();
            }
            if (!graph.current) return;
            context.lineWidth = 2;
            for (let seriesIndex = 0; seriesIndex < graph.series.length; seriesIndex++) {
                const entry = graph.series[seriesIndex];
                if (!entry.current) continue;
                context.strokeStyle = graph.lineColor(seriesIndex);
                context.setLineDash(graph.lineDash(seriesIndex));
                context.beginPath();
                let connected = false;
                for (let index = 0; index < entry.samples.length; index++) {
                    const value = entry.samples[index];
                    if (value === null || !Number.isFinite(value)) { connected = false; continue; }
                    const horizontal = (60 - entry.samples.length + index) * width / 59;
                    const vertical = height - 2 - Math.min(1, Math.max(0, value / Math.max(1,entry.maximum))) * (height - 4);
                    if (connected) context.lineTo(horizontal, vertical); else context.moveTo(horizontal, vertical);
                    connected = true;
                }
                context.stroke();
            }
        }
        Connections {
            target: graph
            function onSeriesChanged() { plot.requestPaint(); }
            function onLineColorsChanged() { plot.requestPaint(); }
        }
    }
    Flickable {
        id: iconLegend
        objectName: graph.objectName + "Legend"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: 36
        contentWidth: iconRow.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Controls.ScrollBar.horizontal: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
        Row {
            id: iconRow
            spacing: 4
            Repeater {
                model: graph.series
                Controls.ToolButton {
                    id: metricIcon
                    required property var modelData
                    required property int index
                    readonly property string description: modelData.title + ": " + (modelData.current ? modelData.reading : "Unavailable") + "; scale 0 - " + Number(modelData.maximum.toFixed(1)) + modelData.unit
                    objectName: graph.objectName + "LegendIcon" + index
                    width: 44 + readoutSize.width
                    height: 32
                    padding: 6
                    spacing: 4
                    text: modelData.reading
                    font.family: Theme.textFont
                    font.pixelSize: 11
                    palette.buttonText: modelData.current ? Theme.paper : Theme.muted
                    palette.highlight: modelData.current ? Theme.paper : Theme.muted
                    palette.highlightedText: modelData.current ? Theme.paper : Theme.muted
                    TextMetrics {
                        id: readoutSize
                        font: metricIcon.font
                        text: Number(metricIcon.modelData.maximum).toFixed(1) + metricIcon.modelData.unit
                    }
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    display: Controls.AbstractButton.TextBesideIcon
                    icon.source: Qt.resolvedUrl("../Assets/Icons/" + modelData.iconName + ".svg")
                    icon.width: 16
                    icon.height: 16
                    icon.color: graph.lineColor(index)
                    Accessible.name: description
                    onActiveFocusChanged: {
                        if (!activeFocus) return;
                        if (x < iconLegend.contentX) iconLegend.contentX = x;
                        else if (x + width > iconLegend.contentX + iconLegend.width)
                            iconLegend.contentX = x + width - iconLegend.width;
                    }
                    background: Rectangle {
                        radius: Theme.radius
                        color: metricIcon.down ? Theme.groupSurface : metricIcon.hovered ? Theme.hover : Theme.clear
                        antialiasing: true
                        border.width: metricIcon.activeFocus ? Theme.controlBorderWidth(metricIcon) : 0
                        border.pixelAligned: false
                        border.color: Theme.paper
                    }
                    Controls.ToolTip {
                        objectName: metricIcon.objectName + "Details"
                        visible: metricIcon.hovered || metricIcon.activeFocus
                        delay: 0
                        timeout: -1
                        scale: {
                            let inheritedScale = 1;
                            let ancestor = metricIcon;
                            while (ancestor) {
                                inheritedScale *= ancestor.scale;
                                ancestor = ancestor.parent;
                            }
                            return inheritedScale;
                        }
                        transformOrigin: Controls.Popup.TopLeft
                        x: -metricIcon.x + iconLegend.contentX
                        width: Math.min(280, graph.width)
                        text: metricIcon.description
                        contentItem: Label { text: metricIcon.description; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; font.pixelSize: 11 }
                        background: Rectangle { color: Theme.ink; border.color: Theme.line; radius: Theme.radius }
                    }
                }
            }
        }
    }
}