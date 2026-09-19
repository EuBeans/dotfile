import QtQuick
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: arrangement
    required property var service
    property var outputs: []
    property string selectedName: ""
    property bool dragging: false
    readonly property bool editable: service.displayControlsEnabled && !service.busy && !service.displayPending
    readonly property var selected: outputs.find(output => output.name === selectedName) || null
    readonly property var bounds: {
        const left = Math.min(0, ...outputs.map(output => output.x));
        const top = Math.min(0, ...outputs.map(output => output.y));
        return {x:left,y:top,width:Math.max(1,...outputs.map(output => output.x + output.width)) - left,
            height:Math.max(1,...outputs.map(output => output.y + output.height)) - top};
    }
    readonly property real viewScale: Math.max(0.001, Math.min((board.width - 32) / bounds.width, (board.height - 32) / bounds.height))
    implicitHeight: 238
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    color: Ui.Theme.clear
    border.color: Ui.Theme.line
    radius: 6

    function reload() {
        if (dragging) return;
        outputs = service.devices.monitors.filter(output => !output.disabled && output.width > 0 && output.height > 0
            && Number.isFinite(output.x) && Number.isFinite(output.y) && output.scale > 0).map(output => ({
                name:output.name,x:output.x,y:output.y,
                width:Math.round((output.transform % 2 ? output.height : output.width) / output.scale),
                height:Math.round((output.transform % 2 ? output.width : output.height) / output.scale)
            }));
        if (!outputs.some(output => output.name === selectedName)) selectedName = outputs.length ? outputs[0].name : "";
    }
    function moveOutput(name, horizontal, vertical, snap) {
        if (!editable || !Number.isFinite(horizontal) || !Number.isFinite(vertical)) return;
        const output = outputs.find(entry => entry.name === name);
        if (!output) return;
        let nextX = Math.round(horizontal);
        let nextY = Math.round(vertical);
        const others = outputs.filter(entry => entry.name !== name);
        if (snap && others.length) {
            const candidates = [];
            const align = (value, start, span, size) => {
                const clamped = Math.max(start - size + 1, Math.min(start + span - 1, value));
                const anchors = [start, start + span - size, Math.round(start + (span - size) / 2)];
                anchors.sort((left, right) => Math.abs(left - clamped) - Math.abs(right - clamped));
                return Math.abs(anchors[0] - clamped) < Math.min(200, 12 / viewScale) ? anchors[0] : clamped;
            };
            for (const other of others) {
                const alignedX = align(nextX, other.x, other.width, output.width);
                const alignedY = align(nextY, other.y, other.height, output.height);
                candidates.push({x:alignedX,y:other.y-output.height}, {x:alignedX,y:other.y+other.height},
                    {x:other.x-output.width,y:alignedY}, {x:other.x+other.width,y:alignedY});
            }
            const valid = candidates.filter(candidate => Math.abs(candidate.x) <= 32768 && Math.abs(candidate.y) <= 32768
                && !others.some(other => candidate.x < other.x + other.width && candidate.x + output.width > other.x
                    && candidate.y < other.y + other.height && candidate.y + output.height > other.y));
            valid.sort((left, right) => Math.hypot(left.x-horizontal,left.y-vertical) - Math.hypot(right.x-horizontal,right.y-vertical));
            if (!valid.length) return;
            nextX = valid[0].x; nextY = valid[0].y;
        }
        for (const other of others) {
            if (nextX < other.x + other.width && nextX + output.width > other.x && nextY < other.y + other.height && nextY + output.height > other.y) {
                const candidates = [{x:other.x-output.width,y:nextY},{x:other.x+other.width,y:nextY},
                    {x:nextX,y:other.y-output.height},{x:nextX,y:other.y+other.height}];
                candidates.sort((left,right) => Math.abs(left.x-nextX)+Math.abs(left.y-nextY)-Math.abs(right.x-nextX)-Math.abs(right.y-nextY));
                nextX = candidates[0].x; nextY = candidates[0].y;
            }
        }
        if (Math.abs(nextX) > 32768 || Math.abs(nextY) > 32768 || (nextX === output.x && nextY === output.y)) return;
        outputs = outputs.map(entry => entry.name === name ? Object.assign({},entry,{x:nextX,y:nextY}) : entry);
        service.displayArrangementRequested([{name:name,x:nextX,y:nextY}]);
    }
    Component.onCompleted: reload()
    Connections {
        target: arrangement.service
        function onDevicesChanged() { arrangement.reload(); }
    }
    Item {
        id: board
        objectName: "monitorArrangementBoard"
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: selection.top; margins: 8 }
        clip: true
        Repeater {
            id: monitorTiles
            model: arrangement.outputs
            Rectangle {
                id: monitorTile
                required property var modelData
                required property int index
                property real dragX: 0
                property real dragY: 0
                objectName: "monitorTile" + modelData.name
                x: (board.width - arrangement.bounds.width * arrangement.viewScale) / 2 + (modelData.x - arrangement.bounds.x) * arrangement.viewScale + dragX
                y: (board.height - arrangement.bounds.height * arrangement.viewScale) / 2 + (modelData.y - arrangement.bounds.y) * arrangement.viewScale + dragY
                width: modelData.width * arrangement.viewScale
                height: modelData.height * arrangement.viewScale
                z: dragArea.activeTile === monitorTile ? 1 : 0
                color: arrangement.selectedName === modelData.name ? Ui.Theme.hover : Ui.Theme.groupSurface
                border.color: arrangement.selectedName === modelData.name ? Ui.Theme.paper : Ui.Theme.line
                border.width: 2
                radius: 4
                activeFocusOnTab: arrangement.editable
                Accessible.name: modelData.name + ", position " + modelData.x + ", " + modelData.y
                Keys.onPressed: event => {
                    const step = event.modifiers & Qt.ShiftModifier ? 100 : 10;
                    const direction = ({[Qt.Key_Left]:[-step,0],[Qt.Key_Right]:[step,0],[Qt.Key_Up]:[0,-step],[Qt.Key_Down]:[0,step]})[event.key];
                    if (!direction) return;
                    arrangement.moveOutput(modelData.name, modelData.x + direction[0], modelData.y + direction[1], false);
                    event.accepted = true;
                }
                onActiveFocusChanged: if (activeFocus) arrangement.selectedName = modelData.name
                Ui.Label { anchors.centerIn: parent; text: monitorTile.index + 1; font.family: Ui.Theme.displayFont; font.pixelSize: 16 }
            }
        }
        MouseArea {
            id: dragArea
            objectName: "monitorArrangementDragArea"
            anchors.fill: parent
            z: 2
            enabled: arrangement.editable
            preventStealing: true
            cursorShape: pressed && activeTile ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property var activeTile: null
            property point origin
            property real startScale: 1
            onPressed: mouse => {
                activeTile = null;
                for (let index = monitorTiles.count - 1; index >= 0; index--) {
                    const tile = monitorTiles.itemAt(index);
                    if (mouse.x >= tile.x && mouse.x <= tile.x + tile.width && mouse.y >= tile.y && mouse.y <= tile.y + tile.height) {
                        activeTile = tile;
                        break;
                    }
                }
                if (!activeTile) { mouse.accepted = false; return; }
                activeTile.forceActiveFocus();
                origin = Qt.point(mouse.x, mouse.y);
                startScale = arrangement.viewScale;
                arrangement.dragging = true;
            }
            onPositionChanged: mouse => {
                if (!pressed || !activeTile) return;
                activeTile.dragX = mouse.x - origin.x;
                activeTile.dragY = mouse.y - origin.y;
            }
            onReleased: {
                if (!activeTile) return;
                const name = activeTile.modelData.name;
                const horizontal = activeTile.modelData.x + activeTile.dragX / startScale;
                const vertical = activeTile.modelData.y + activeTile.dragY / startScale;
                const moved = Math.abs(activeTile.dragX) + Math.abs(activeTile.dragY) >= 3;
                activeTile.dragX = 0; activeTile.dragY = 0;
                activeTile = null;
                arrangement.dragging = false;
                if (moved) arrangement.moveOutput(name, horizontal, vertical, true);
            }
            onCanceled: {
                if (activeTile) { activeTile.dragX = 0; activeTile.dragY = 0; }
                activeTile = null;
                arrangement.dragging = false;
                arrangement.reload();
            }
        }
    }
    Ui.Label {
        id: selection
        objectName: "monitorArrangementSelection"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
        text: arrangement.selected ? arrangement.selected.name + " / " + arrangement.selected.x + ", " + arrangement.selected.y : "No active monitors"
        wrapMode: Text.WrapAnywhere
        font.pixelSize: 11
        color: Ui.Theme.muted
    }
}