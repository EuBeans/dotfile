import QtQuick

Item {
    id: meter
    property real value: 0
    property bool available: true
    property string label: "Usage"
    property bool reducedMotion: false
    property bool initialized: false
    property real displayedValue: 0
    readonly property int displayedSegments: Math.floor(displayedValue * segments)
    readonly property bool animating: fillAnimation.running
    readonly property int segments: 20
    readonly property real boundedValue: available && isFinite(value) ? Math.max(0, Math.min(1, value)) : 0
    readonly property int filledSegments: Math.floor(boundedValue * segments)
    onBoundedValueChanged: displayedValue = boundedValue
    Component.onCompleted: { displayedValue = boundedValue; initialized = true; }
    onVisibleChanged: {
        if (!visible) { fillAnimation.stop(); displayedValue = boundedValue; }
    }
    onReducedMotionChanged: {
        if (reducedMotion) { fillAnimation.stop(); displayedValue = boundedValue; }
    }
    Behavior on displayedValue {
        enabled: meter.initialized && meter.visible && !meter.reducedMotion && meter.available
        NumberAnimation { id: fillAnimation; duration: 320; easing.type: Easing.OutCubic }
    }
    implicitWidth: 360
    implicitHeight: 38
    Accessible.role: Accessible.ProgressBar
    Accessible.name: label
    Accessible.description: available && isFinite(value) ? Math.round(boundedValue * 100) + "%" : "Unavailable"

    Rectangle {
        anchors.fill: parent
        color: Theme.clear
        border.width: 2
        border.color: Theme.muted
        radius: 2
        antialiasing: true
    }
    Canvas {
        id: drawing
        anchors.fill: parent
        anchors.margins: 5
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            const gap = 5;
            const segmentWidth = (width - gap * (meter.segments - 1)) / meter.segments;
            for (let segment = 0; segment < meter.segments; segment++) {
                const left = segment * (segmentWidth + gap);
                if (segment < meter.displayedSegments) {
                    context.fillStyle = Theme.paper;
                    context.fillRect(left, 0, segmentWidth, height);
                } else {
                    context.fillStyle = Theme.line;
                    for (let column = 0; column < segmentWidth - 1; column += 3) {
                        for (let row = 0; row < height - 1; row += 3)
                            context.fillRect(left + column, row, 1, 1);
                    }
                }
            }
        }
    }
    onDisplayedSegmentsChanged: drawing.requestPaint()
    onAvailableChanged: drawing.requestPaint()
    Connections {
        target: Theme
        function onPaperChanged() { drawing.requestPaint(); }
        function onLineChanged() { drawing.requestPaint(); }
    }
}