import QtQuick

FocusScope {
    id: drawer
    property bool opened: false
    property bool reducedMotion: false
    property string edge: "top"
    property bool floating: Theme.floatingPanels
    property bool slide: false
    property real progress: 0
    readonly property bool instant: reducedMotion || Theme.animationStyle === "Off" || Theme.animationDuration === 0
    readonly property real steppedProgress: Theme.animatedProgress(progress)
    readonly property bool animating: motion.running
    default property alias content: surface.data
    signal dismissRequested()
    clip: true
    visible: opened || progress > 0
    enabled: opened
    onOpenedChanged: {
        motion.stop();
        if (instant) progress = opened ? 1 : 0;
        else { motion.to = opened ? 1 : 0; motion.start(); }
        if (opened) forceActiveFocus();
    }
    onInstantChanged: {
        if (instant) { motion.stop(); progress = opened ? 1 : 0; }
    }
    Keys.onEscapePressed: dismissRequested()
    NumberAnimation { id: motion; target: drawer; property: "progress"; duration: Theme.animationDuration; easing.type: Theme.animationStyle === "Stepped" ? Easing.Linear : Easing.OutCubic }
    Item {
        id: reveal
        objectName: drawer.objectName + "Reveal"
        width: !drawer.slide && !drawer.floating && (drawer.edge === "right" || drawer.edge === "left") ? drawer.width * drawer.steppedProgress : drawer.width
        height: !drawer.slide && !drawer.floating && drawer.edge === "top" ? drawer.height * drawer.steppedProgress : drawer.height
        x: !drawer.slide && drawer.edge === "right" ? drawer.width - width : 0
        opacity: !drawer.slide && drawer.floating ? drawer.steppedProgress : 1
        clip: true
        Item {
            id: surface
            objectName: drawer.objectName + "Surface"
            width: drawer.width
            height: drawer.height
            x: drawer.slide ? (drawer.edge === "right" ? 1 : drawer.edge === "left" ? -1 : 0) * (1 - drawer.steppedProgress) * drawer.width
                : -reveal.x + (drawer.floating && drawer.edge === "right" ? (1 - drawer.steppedProgress) * 16 : drawer.floating && drawer.edge === "left" ? -(1 - drawer.steppedProgress) * 16 : 0)
            y: drawer.edge === "top" ? -(1 - drawer.steppedProgress) * (drawer.slide ? drawer.height : drawer.floating ? 12 : 0) : 0
            MouseArea { anchors.fill: parent }
        }
    }
}