import QtQuick
import QtQuick.Layouts
import "../shell/Components" as Ui

GridLayout {
    id: widgets
    objectName: "lockWidgets"
    required property var service
    readonly property bool live: service.production === true
    property int sample: 0
    property var history: live ? service.lockHistory : [[], [], []]
    readonly property var series: live ? service.lockSeries : [
        {name: "CPU", value: 8, detail: "9950X3D"},
        {name: service.gpus[0].name, value: service.gpus[0].utilization, detail: service.gpus[0].usedGiB.toFixed(1) + " / " + service.gpus[0].totalGiB + " GiB"},
        {name: service.gpus[1].name, value: service.gpus[1].utilization, detail: service.gpus[1].usedGiB.toFixed(1) + " / " + service.gpus[1].totalGiB + " GiB"}
    ]
    columns: width >= 620 ? 2 : 1
    columnSpacing: 12
    rowSpacing: 12

    function advance() {
        if (live) return;
        sample++;
        history = series.map((entry, index) => {
            const previous = history[index];
            const value = Math.max(0, Math.min(100, entry.value + Math.sin(sample * 0.7 + index * 2) * 7 + Math.cos(sample * 1.8 + index) * 4));
            return previous.slice(-47).concat([value]);
        });
    }
    Component.onCompleted: {
        for (let index = 0; index < 48; index++) advance();
    }
    Timer { interval: 1000; repeat: true; running: !widgets.live && widgets.visible && widgets.service.telemetryAvailable; onTriggered: widgets.advance() }

    Rectangle {
        objectName: "lockSystemWidget"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 430
        Layout.preferredHeight: 208
        color: Ui.Theme.ink
        radius: 6
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Ui.Label { text: "SYSTEM"; font.pixelSize: 11; Layout.fillWidth: true }
                Ui.Label { text: widgets.service.telemetryAvailable ? (widgets.live ? "LIVE / 96s" : "DEMO / 48s") : "UNAVAILABLE"; font.pixelSize: 9; color: Ui.Theme.muted }
            }
            Canvas {
                id: graph
                objectName: "lockSystemGraph"
                Layout.fillWidth: true
                Layout.preferredHeight: 78
                property var history: widgets.history
                property bool available: widgets.service.telemetryAvailable
                property color paper: Ui.Theme.paper
                property color muted: Ui.Theme.muted
                property color line: Ui.Theme.line
                onHistoryChanged: requestPaint()
                onAvailableChanged: requestPaint()
                onPaperChanged: requestPaint()
                onMutedChanged: requestPaint()
                onLineChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Accessible.role: Accessible.Graphic
                Accessible.name: available ? (widgets.live ? "CPU and GPU utilization history" : "Simulated CPU and GPU utilization history") : "System telemetry unavailable"
                onPaint: {
                    const context = getContext("2d");
                    context.reset();
                    context.clearRect(0, 0, width, height);
                    context.strokeStyle = line;
                    context.lineWidth = 1;
                    for (let row = 0; row < 3; row++) {
                        const ordinate = 1 + row * (height - 2) / 2;
                        context.beginPath();
                        context.moveTo(0, ordinate);
                        context.lineTo(width, ordinate);
                        context.stroke();
                    }
                    if (!available) return;
                    for (let seriesIndex = 0; seriesIndex < history.length; seriesIndex++) {
                        const values = history[seriesIndex];
                        context.strokeStyle = seriesIndex === 0 ? muted : paper;
                        context.lineWidth = seriesIndex === 1 ? 2 : 1;
                        context.setLineDash(seriesIndex === 2 ? [3, 3] : []);
                        context.beginPath();
                        let connected = false;
                        for (let pointIndex = 0; pointIndex < values.length; pointIndex++) {
                            if (!Number.isFinite(values[pointIndex])) { connected = false; continue; }
                            const abscissa = pointIndex * width / 47;
                            const ordinate = height - 2 - values[pointIndex] / 100 * (height - 4);
                            if (!connected) context.moveTo(abscissa, ordinate);
                            else context.lineTo(abscissa, ordinate);
                            connected = true;
                        }
                        context.stroke();
                    }
                }
            }
            Repeater {
                model: widgets.series
                RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 8
                    Ui.Label { text: index === 2 ? "- -" : "___"; font.pixelSize: 9; color: index === 0 ? Ui.Theme.muted : Ui.Theme.paper }
                    Ui.Label { text: modelData.name; font.pixelSize: 10; Layout.fillWidth: true; Layout.minimumWidth: 0 }
                    Ui.Label { text: widgets.service.telemetryAvailable && Number.isFinite(modelData.value) ? Math.round(modelData.value) + "%" : "N/A"; font.pixelSize: 10; Layout.preferredWidth: 34 }
                    Ui.Label { text: widgets.service.telemetryAvailable ? modelData.detail : "--"; font.pixelSize: 9; color: Ui.Theme.muted; Layout.preferredWidth: 104; horizontalAlignment: Text.AlignRight }
                }
            }
        }
    }

    Rectangle {
        objectName: "lockWeatherWidget"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 290
        Layout.preferredHeight: 208
        color: Ui.Theme.ink
        radius: 6
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Ui.Label { text: "WEATHER"; font.pixelSize: 11; Layout.fillWidth: true }
                Ui.Label { text: "OFFLINE"; font.pixelSize: 9; color: Ui.Theme.muted }
            }
            Ui.Label { text: "--"; font.family: Ui.Theme.displayFont; font.pixelSize: 36; Layout.fillWidth: true }
            Ui.Label { objectName: "lockWeatherStatus"; text: "Location not configured"; font.pixelSize: 10; color: Ui.Theme.muted; Layout.fillWidth: true }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: 3
                    ColumnLayout {
                        required property int index
                        Layout.fillWidth: true
                        spacing: 5
                        Ui.Label { text: Qt.formatDate(new Date(widgets.service.calendarDate.getFullYear(), widgets.service.calendarDate.getMonth(), widgets.service.calendarDate.getDate() + index + 1), "ddd"); font.pixelSize: 10; color: Ui.Theme.muted; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                        Ui.Label { text: "-- / --"; font.pixelSize: 10; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}