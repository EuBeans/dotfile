import QtQuick

Canvas {
    id: notch
    property color fillColor: Theme.ink
    property bool floating: false
    readonly property real cornerRadius: Math.min(Theme.barRadius, height / 2)
    onFloatingChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const context = getContext("2d");
        context.reset();
        context.fillStyle = fillColor;
        context.beginPath();
        if (floating) {
            context.roundedRect(14, 0, Math.max(0, width - 28), height, cornerRadius, cornerRadius);
            context.fill();
            return;
        }
        context.moveTo(0, 0);
        context.lineTo(14 - Math.min(14, cornerRadius), 0);
        context.quadraticCurveTo(14, 0, 14, cornerRadius);
        context.lineTo(14, height - cornerRadius);
        context.quadraticCurveTo(14, height, 14 + cornerRadius, height);
        context.lineTo(width - 14 - cornerRadius, height);
        context.quadraticCurveTo(width - 14, height, width - 14, height - cornerRadius);
        context.lineTo(width - 14, cornerRadius);
        context.quadraticCurveTo(width - 14, 0, width - 14 + Math.min(14, cornerRadius), 0);
        context.lineTo(width, 0);
        context.closePath();
        context.fill();
    }
}