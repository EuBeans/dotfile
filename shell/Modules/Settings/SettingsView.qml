import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: settings
    property bool embedded: false
    property bool production: false
    property bool singleSection: false
    required property var service
    required property var shortcuts
    readonly property bool compactNavigation: embedded || width < 600
    property int section: 0
    readonly property var categoryGroups: ["Personalize", "Personalize", "Personalize", "Personalize", "Session", "Session", "Session", "Hardware", "Hardware"]
    readonly property var searchTerms: ["glass opacity corners radius panels windows", "colors palette wallpaper save copy policies", "tiling gaps borders placement attached floating bars", "animation duration reduced accessibility", "keyboard bindings hotkeys", "volume mute output devices pipewire", "dnd do not disturb alerts", "model inference gpu vram", "cpu gpu memory telemetry status"]
    readonly property var matches: categories.map((category, index) => ({category: category, index: index})).filter(entry => (entry.category.name + " " + categoryGroups[entry.index] + " " + searchTerms[entry.index]).toLowerCase().includes(settingsSearch.text.trim().toLowerCase()))
    readonly property var categories: [
        {
            name: "Appearance",
            key: "appearance"
        },
        {
            name: "Themes / Profiles",
            key: "profiles"
        },
        {
            name: "Desktop",
            key: "desktop"
        },
        {
            name: "Motion",
            key: "motion"
        },
        {
            name: "Shortcuts",
            key: "shortcuts"
        },
        {
            name: "Audio",
            key: "audio"
        },
        {
            name: "Notifications",
            key: "notifications"
        },
        {
            name: "Local AI",
            key: "ai"
        },
        {
            name: "System",
            key: "system"
        }
    ]
    function openCategory(index) {
        section = index;
        settingsSearch.clear();
        pageScroll.forceActiveFocus();
    }
    onSectionChanged: {
        shortcuts.recording = "";
        pageScroll.contentItem.contentY = 0;
    }
    objectName: "settingsSurface"
    color: embedded ? Ui.Theme.clear : Ui.Theme.windowSurface
    radius: Ui.Theme.windowRadius
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: settings.embedded ? 0 : 16
        spacing: 12
        RowLayout {
            visible: !settings.embedded
            Layout.fillWidth: true
            Ui.Label {
                text: "SETTINGS"
                font.family: Ui.Theme.displayFont
                font.pixelSize: 18
                Layout.fillWidth: true
            }
            Ui.Label {
                text: settings.service.profile
                Layout.maximumWidth: 140
                color: Ui.Theme.muted
            }
        }
        Rectangle {
            visible: !settings.embedded
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Ui.Theme.line
        }
        RowLayout {
            visible: !settings.singleSection
            Layout.fillWidth: true
            spacing: 8
            Ui.TextField {
                id: settingsSearch
                objectName: "settingsSearch"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                placeholderText: "Find a setting"
                Accessible.name: "Find a setting"
                onAccepted: if (settings.matches.length) settings.openCategory(settings.matches[0].index)
                Keys.onEscapePressed: event => { clear(); event.accepted = true; }
            }
            Ui.ActionButton {
                objectName: "clearSettingsSearch"
                iconName: "x"
                description: "Clear settings search"
                enabled: settingsSearch.text.length > 0
                onClicked: { settingsSearch.clear(); settingsSearch.forceActiveFocus(); }
            }
        }
        Ui.Dropdown {
            objectName: settings.embedded ? "homeSettingsCategory" : "settingsCategory"
            visible: settings.compactNavigation && !settings.singleSection && settingsSearch.text.trim() === ""
            Layout.fillWidth: true
            model: settings.categories.map(category => category.name)
            currentIndex: settings.section
            Accessible.name: "Settings category"
            onActivated: settings.section = currentIndex
        }
        RowLayout {
            visible: settingsSearch.text.trim() === ""
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16
            ScrollView {
                id: categoryScroll
                objectName: "settingsCategoryScroll"
                visible: !settings.compactNavigation
                Layout.preferredWidth: 156
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: categoryScroll.availableWidth
                    spacing: 2
                    Repeater {
                        model: settings.categories
                        ColumnLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 2
                            Ui.Label {
                                text: settings.categoryGroups[index].toUpperCase()
                                visible: index === 0 || settings.categoryGroups[index - 1] !== settings.categoryGroups[index]
                                font.pixelSize: 9
                                color: Ui.Theme.muted
                                Layout.topMargin: index === 0 ? 0 : 8
                                Layout.bottomMargin: 4
                            }
                            Ui.ActionButton {
                                objectName: modelData.key + "Tab"
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                implicitHeight: 30
                                text: modelData.name
                                font.pixelSize: 11
                                checked: settings.section === index
                                Accessible.role: Accessible.PageTab
                                onClicked: settings.section = index
                                contentItem: Ui.Label {
                                    text: parent.text
                                    font.pixelSize: 11
                                    color: parent.checked || parent.down ? Ui.Theme.ink : Ui.Theme.paper
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                visible: !settings.compactNavigation
                Layout.fillHeight: true
                implicitWidth: 1
                color: Ui.Theme.line
            }
            ScrollView {
                id: pageScroll
                objectName: "settingsPageScroll"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: pageScroll.availableWidth
                    spacing: 12
                    Ui.Label {
                        objectName: "settingsPageTitle"
                        visible: !settings.singleSection
                        text: settings.categories[settings.section].name
                        font.family: Ui.Theme.displayFont
                        font.pixelSize: 16
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }
                    Ui.SettingsSection {
                        objectName: "profileSection"
                        title: "Profiles"
                        visible: settings.section === 1
                        Ui.Dropdown {
                            objectName: "profileSelect"
                            model: settings.service.profileSettings.profiles.map(entry => entry.name)
                            currentIndex: model.indexOf(settings.service.profile)
                            Accessible.name: "Profile"
                            onActivated: settings.production ? settings.service.applyProfile(currentText) : profilePolicies.item.confirmSwitch(currentText)
                        }
                        Ui.Label { text: "Profile name"; color: Ui.Theme.muted; font.pixelSize: 11 }
                        RowLayout {
                            Layout.fillWidth: true
                            Ui.TextField {
                                id: profileName
                                objectName: "profileName"
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                maximumLength: 32
                                placeholderText: "Profile name"
                                font.family: Ui.Theme.textFont
                                onAccepted: if (settings.service.profileSettings.add(text))
                                    text = ""
                            }
                            Ui.ActionButton {
                                objectName: "addProfile"
                                text: "Create"
                                onClicked: if (settings.service.profileSettings.add(profileName.text))
                                    profileName.text = ""
                            }
                        }
                        Ui.Label {
                            text: settings.service.profileSettings.error
                            visible: text !== ""
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Ui.ActionButton { text: "Save as new"; enabled: profileName.text.trim() !== ""; onClicked: if (settings.service.profileSettings.add(profileName.text)) profileName.text = "" }
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "paletteSection"
                        title: "Colors"
                        visible: settings.section === 1 && !settings.singleSection
                        RowLayout {
                            Repeater {
                                model: ["Saved", "Wallpaper"]
                                Ui.ActionButton {
                                    required property string modelData
                                    objectName: "source" + modelData
                                    enabled: !settings.production || modelData === "Saved" || settings.service.wallpaperColorsAvailable
                                    text: modelData
                                    checked: settings.service.profileSettings.currentProfile.source === modelData
                                    onClicked: settings.service.profileSettings.update("source", modelData)
                                }
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            enabled: settings.service.profileSettings.currentProfile.source === "Saved"
                            Repeater {
                                model: settings.service.profileSettings.paletteNames
                                Ui.ActionButton {
                                    required property string modelData
                                    objectName: "palette" + modelData
                                    description: modelData
                                    implicitWidth: 86
                                    implicitHeight: 58
                                    checked: settings.service.profileSettings.currentProfile.palette === modelData
                                    onClicked: settings.service.profileSettings.update("palette", modelData)
                                    contentItem: ColumnLayout {
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 20
                                            color: settings.service.profileSettings.palettes[modelData].ink
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 28
                                                height: 12
                                                color: settings.service.profileSettings.palettes[modelData].accent
                                            }
                                        }
                                        Ui.Label {
                                            text: modelData
                                            font.pixelSize: 11
                                            color: parent.parent.checked ? Ui.Theme.ink : Ui.Theme.paper
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "wallpaperSection"
                        title: "Wallpaper"
                        visible: settings.section === 1 && !settings.singleSection
                        Ui.Dropdown {
                            objectName: "profileWallpaper"
                            model: settings.service.wallpapers.map(entry => entry.name)
                            currentIndex: settings.service.wallpaper
                            Accessible.name: "Profile wallpaper"
                            onActivated: settings.service.setWallpaper(currentIndex)
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "glassSection"
                        title: "Glass and opacity"
                        visible: settings.section === 0
                        Ui.Toggle {
                            objectName: "glassSwitch"
                            text: "Glass"
                            checked: settings.service.profileSettings.glassEnabled
                            onToggled: settings.service.profileSettings.glassEnabled = checked
                        }
                        Repeater {
                            model: [
                                {
                                    key: "panelOpacity",
                                    label: "Panel opacity",
                                    minimum: 40,
                                    maximum: 100,
                                    unit: "%"
                                },
                                {
                                    key: "windowOpacity",
                                    label: "Window opacity",
                                    minimum: 40,
                                    maximum: 100,
                                    unit: "%"
                                }
                            ]
                            Ui.SettingRow {
                                required property var modelData
                                Layout.fillWidth: true
                                enabled: (!settings.production || modelData.key !== "windowOpacity" || settings.service.desktopControlsEnabled) && (modelData.unit !== "%" || settings.service.profileSettings.glassEnabled)
                                label: modelData.label
                                Ui.ValueControl {
                                    objectName: modelData.key + "Setting"
                                    from: modelData.minimum
                                    to: modelData.maximum
                                    value: settings.service.profileSettings[modelData.key]
                                    Accessible.name: modelData.label
                                    onValueModified: value => settings.service.profileSettings.setAppearance(modelData.key, value)
                                }
                                Ui.Label {
                                    text: modelData.unit
                                    color: Ui.Theme.muted
                                    Layout.preferredWidth: 24
                                }
                            }
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "cornersSection"
                        title: "Corners"
                        visible: settings.section === 0
                        Repeater {
                            model: [
                                {
                                    key: "panelRadius",
                                    label: "Panels"
                                },
                                {
                                    key: "barRadius",
                                    label: "Bar and notch"
                                },
                                {
                                    key: "windowRadius",
                                    label: "Windows"
                                }
                            ]
                            Ui.SettingRow {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.label
                                Ui.ValueControl {
                                    objectName: modelData.key + "Setting"
                                    from: 0
                                    to: 24
                                    enabled: !settings.production || modelData.key !== "windowRadius" || settings.service.desktopControlsEnabled
                                    value: settings.service.profileSettings[modelData.key]
                                    Accessible.name: modelData.label + " corner radius"
                                    onValueModified: value => settings.service.profileSettings.setAppearance(modelData.key, value)
                                }
                                Ui.Label {
                                    text: "px"
                                    color: Ui.Theme.muted
                                }
                            }
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "panelsSection"
                        title: "Panel placement"
                        visible: settings.section === 2
                        RowLayout {
                            Ui.ActionButton {
                                objectName: "panelsAttached"
                                text: "Attached"
                                checked: !settings.service.profileSettings.floatingPanels
                                onClicked: settings.service.profileSettings.floatingPanels = false
                            }
                            Ui.ActionButton {
                                objectName: "panelsFloating"
                                text: "Floating"
                                checked: settings.service.profileSettings.floatingPanels
                                onClicked: settings.service.profileSettings.floatingPanels = true
                            }
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "barPlacementSection"
                        title: "Top bar placement"
                        visible: settings.section === 2
                        Repeater {
                            model: [
                                {key: "floatingLeftBar", label: "Left"},
                                {key: "floatingMiddleBar", label: "Middle"},
                                {key: "floatingRightBar", label: "Right"}
                            ]
                            Ui.SettingRow {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.label
                                Ui.ActionButton {
                                    objectName: modelData.key + "Attached"
                                    text: "Attached"
                                    iconOnly: false
                                    checked: !settings.service.profileSettings[modelData.key]
                                    description: modelData.label + " bar attached"
                                    onClicked: settings.service.profileSettings[modelData.key] = false
                                }
                                Ui.ActionButton {
                                    objectName: modelData.key + "Floating"
                                    text: "Floating"
                                    iconOnly: false
                                    checked: settings.service.profileSettings[modelData.key]
                                    description: modelData.label + " bar floating"
                                    onClicked: settings.service.profileSettings[modelData.key] = true
                                }
                            }
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "windowLayoutSection"
                        enabled: !settings.production || settings.service.desktopControlsEnabled
                        title: "Window layout"
                        visible: settings.section === 2
                        Ui.SettingRow {
                            Layout.fillWidth: true
                            label: "Tiling mode"
                            Ui.Dropdown {
                                objectName: "settingsTilingLayout"
                                Layout.maximumWidth: 180
                                readonly property var layoutKeys: ["Auto", "Split", "Columns", "Centered"]
                                model: settings.production ? ["Current / default", "Dwindle", "Master", "Centered"] : layoutKeys
                                currentIndex: layoutKeys.indexOf(settings.service.profileSettings.tilingLayout)
                                Accessible.name: "Tiling mode"
                                onActivated: settings.service.profileSettings.setAppearance("tilingLayout", layoutKeys[currentIndex])
                            }
                        }
                        Ui.SettingRow {
                            Layout.fillWidth: true
                            enabled: settings.production ? ["Columns", "Centered"].includes(settings.service.profileSettings.tilingLayout) : settings.service.profileSettings.tilingLayout !== "Columns"
                            label: "Main pane width"
                            Ui.ValueControl {
                                objectName: "mainPaneRatioSetting"
                                from: 30
                                to: 70
                                value: settings.service.profileSettings.mainPaneRatio
                                Accessible.name: "Main pane width"
                                onValueModified: value => settings.service.profileSettings.setAppearance("mainPaneRatio", value)
                            }
                            Ui.Label { text: "%"; color: Ui.Theme.muted; Layout.preferredWidth: 24 }
                        }
                        Ui.SettingRow {
                            Layout.fillWidth: true
                            label: "Window border"
                            Ui.ValueControl {
                                objectName: "windowBorderWidthSetting"
                                from: 0
                                to: 8
                                value: settings.service.profileSettings.windowBorderWidth
                                Accessible.name: "Window border width"
                                onValueModified: value => settings.service.profileSettings.setAppearance("windowBorderWidth", value)
                            }
                            Ui.Label { text: "px"; color: Ui.Theme.muted; Layout.preferredWidth: 24 }
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "tilingSection"
                        enabled: !settings.production || settings.service.desktopControlsEnabled
                        title: "Window gaps"
                        visible: settings.section === 2
                        Repeater {
                            model: [
                                {
                                    key: "tileGap",
                                    label: "Between tiles",
                                    maximum: 32
                                },
                                {
                                    key: "outerGap",
                                    label: "Screen-edge gap",
                                    maximum: 64
                                }
                            ]
                            Ui.SettingRow {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.label
                                Ui.ValueControl {
                                    objectName: modelData.key + "Setting"
                                    from: 0
                                    to: modelData.maximum
                                    value: settings.service.profileSettings[modelData.key]
                                    Accessible.name: modelData.label
                                    onValueModified: value => settings.service.profileSettings.setAppearance(modelData.key, value)
                                }
                                Ui.Label {
                                    text: "px"
                                    color: Ui.Theme.muted
                                }
                            }
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "motionSection"
                        title: "Accessibility"
                        visible: settings.section === 3
                        Ui.Toggle {
                            objectName: "reducedMotionSwitch"
                            text: "Reduced motion"
                            checked: settings.service.reducedMotion
                            onToggled: settings.service.reducedMotion = checked
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "animationSection"
                        title: "Panel animation"
                        visible: settings.section === 3
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            enabled: !settings.service.reducedMotion
                            Repeater {
                                model: ["Stepped", "Smooth", "Off"]
                                Ui.ActionButton {
                                    required property string modelData
                                    objectName: "animation" + modelData
                                    text: modelData
                                    checked: settings.service.profileSettings.animationStyle === modelData
                                    onClicked: settings.service.profileSettings.setAppearance("animationStyle", modelData)
                                }
                            }
                        }
                        Ui.SettingRow {
                            Layout.fillWidth: true
                            enabled: settings.service.profileSettings.animationStyle !== "Off" && !settings.service.reducedMotion
                            label: "Duration"
                            Ui.ValueControl {
                                objectName: "animationDurationSetting"
                                from: 0
                                to: 800
                                stepSize: 20
                                value: settings.service.profileSettings.animationDuration
                                Accessible.name: "Animation duration"
                                onValueModified: value => settings.service.profileSettings.setAppearance("animationDuration", value)
                            }
                            Ui.Label {
                                text: "ms"
                                color: Ui.Theme.muted
                            }
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "bindingsSection"
                        enabled: !settings.production || (settings.service.desktopControlsEnabled && settings.shortcuts.ready && !settings.shortcuts.busy)
                        title: "Key bindings"
                        visible: settings.section === 4
                        Repeater {
                            model: settings.shortcuts.actions
                            Ui.SettingRow {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.label
                                Ui.ActionButton {
                                    objectName: "bind_" + modelData.key
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: settings.width < 800 ? 148 : 184
                                    font.pixelSize: 11
                                    text: settings.shortcuts.recording === modelData.key ? "Press keys..." : (settings.shortcuts.binding(modelData.key) || "Unassigned")
                                    description: "Rebind " + modelData.label
                                    checked: settings.shortcuts.recording === modelData.key
                                    onClicked: {
                                        settings.shortcuts.error = "";
                                        settings.shortcuts.recording = modelData.key;
                                        forceActiveFocus();
                                    }
                                    Keys.priority: Keys.BeforeItem
                                    Keys.onPressed: event => {
                                        if (settings.shortcuts.recording === modelData.key)
                                            settings.shortcuts.recordKey(event);
                                    }
                                    onActiveFocusChanged: {
                                        if (!activeFocus && settings.shortcuts.recording === modelData.key)
                                            settings.shortcuts.recording = "";
                                    }
                                }
                                Ui.ActionButton {
                                    objectName: "clear_" + modelData.key
                                    iconName: "x"
                                    description: "Clear " + modelData.label
                                    onClicked: settings.shortcuts.saveBinding(modelData.key, "")
                                }
                                Ui.ActionButton {
                                    objectName: "reset_" + modelData.key
                                    iconName: "rotate-ccw"
                                    description: "Reset " + modelData.label
                                    onClicked: settings.shortcuts.saveBinding(modelData.key, modelData.sequence)
                                }
                            }
                        }
                        Ui.Label {
                            text: settings.shortcuts.error
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                            Layout.fillWidth: true
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "audioOutputSection"
                        enabled: !settings.production || (settings.service.desktopData.controlsEnabled && settings.service.defaultSink !== null && !settings.service.desktopData.busy)
                        title: "Output"
                        visible: settings.section === 5
                        RowLayout {
                            Layout.fillWidth: true
                            Ui.Label {
                                text: "Volume"
                                Layout.fillWidth: true
                            }
                            Ui.Label {
                                text: settings.service.volume + "%"
                            }
                        }
                        Ui.ValueSlider {
                            objectName: "settingsVolume"
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            stepSize: 1
                            value: settings.service.volume
                            Accessible.name: "Output volume"
                            onMoved: {
                                if (settings.production) settings.service.volumeRequested(Math.round(value));
                                else settings.service.volume = Math.round(value);
                            }
                        }
                        Ui.Toggle {
                            objectName: "settingsOutputMute"
                            text: "Mute output"
                            checked: settings.service.outputMuted
                            onToggled: {
                                if (settings.production) settings.service.outputMuteRequested(checked);
                                else settings.service.outputMuted = checked;
                            }
                        }
                    }
                    Loader {
                        id: profilePolicies
                        Layout.fillWidth: true
                        active: !settings.production
                        visible: !settings.production && settings.section === 1
                        sourceComponent: ProfilePolicies { service: settings.service }
                    }
                    Ui.SettingsSection {
                        objectName: "audioDevicesSection"
                        title: "Devices"
                        visible: settings.section === 5
                        Ui.Label {
                            text: settings.production ? (settings.service.defaultSink ? settings.service.defaultSink.description || settings.service.defaultSink.name : "No output device") : "PipeWire: not connected"
                            color: Ui.Theme.muted
                            Layout.fillWidth: true
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "notificationsSection"
                        title: "Do not disturb"
                        visible: settings.section === 6
                        Ui.Toggle {
                            objectName: "settingsDnd"
                            text: "Do not disturb"
                            checked: settings.service.dndEnabled
                            onToggled: settings.service.dndEnabled = checked
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "notificationServiceSection"
                        title: "Notification service"
                        visible: settings.section === 6
                        Ui.Label {
                            text: settings.production ? (settings.service.preferences.notificationsEnabled ? "Desktop notification server enabled" : "Desktop notification server disabled") : "Desktop service: not connected"
                            color: Ui.Theme.muted
                            Layout.fillWidth: true
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "aiRuntimeSection"
                        title: "Runtime"
                        visible: settings.section === 7
                        Ui.Label {
                            text: settings.production ? "Backend: setup deferred" : "Backend: preview"
                            color: Ui.Theme.muted
                        }
                        Ui.Label {
                            text: "Status: " + settings.service.aiStatus
                        }
                        Ui.Label {
                            text: settings.service.loadedModelIndex >= 0 ? settings.service.models[settings.service.loadedModelIndex] : "No model loaded"
                            Layout.fillWidth: true
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "aiModelsSection"
                        title: "Models"
                        visible: settings.section === 7
                        Repeater {
                            model: settings.service.models
                            Ui.Label {
                                required property string modelData
                                text: modelData
                                Layout.fillWidth: true
                            }
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "systemSection"
                        title: "Session"
                        visible: settings.section === 8
                        Ui.Label {
                            text: settings.production ? "Runtime: Quickshell" : "Runtime: native Qt preview"
                            Layout.fillWidth: true
                        }
                        Ui.Label {
                            text: settings.production ? "Hyprland: connected" : "Hyprland: not connected"
                            color: Ui.Theme.muted
                            Layout.fillWidth: true
                        }
                        Ui.Label {
                            text: settings.production ? (settings.service.telemetryAvailable ? "GPU telemetry: live" : "GPU telemetry: unavailable") : "GPU telemetry: simulated"
                            color: Ui.Theme.muted
                            Layout.fillWidth: true
                        }
                    }
                    Ui.SettingsSection {
                        objectName: "storageSection"
                        title: "Preferences"
                        visible: settings.section === 8
                        Ui.Label {
                            text: "Profiles and appearance: saved locally"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                        Ui.Label {
                            text: settings.production ? "Motion override and DND: saved locally" : "Audio, motion override and DND: session only"
                            color: Ui.Theme.muted
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                    }
                }
            }
        }
        ListView {
            id: searchResults
            objectName: "settingsSearchResults"
            visible: settingsSearch.text.trim() !== ""
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: settings.matches
            ScrollBar.vertical: ScrollBar {}
            delegate: Ui.ActionButton {
                required property var modelData
                objectName: "settingsResult" + modelData.category.key
                width: searchResults.width
                height: 52
                text: modelData.category.name
                description: settings.categoryGroups[modelData.index] + ": " + text
                onClicked: settings.openCategory(modelData.index)
                contentItem: ColumnLayout {
                    spacing: 4
                    Ui.Label { text: modelData.category.name; Layout.fillWidth: true; color: parent.parent.down ? Ui.Theme.ink : Ui.Theme.paper }
                    Ui.Label { text: settings.categoryGroups[modelData.index]; Layout.fillWidth: true; font.pixelSize: 10; color: parent.parent.down ? Ui.Theme.ink : Ui.Theme.muted }
                }
            }
            Ui.Label {
                objectName: "settingsSearchEmpty"
                visible: searchResults.count === 0
                width: parent.width
                text: "No matching settings"
                wrapMode: Text.WordWrap
                color: Ui.Theme.muted
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
        RowLayout {
            objectName: "settingsProfileActions"
            Layout.fillWidth: true
            spacing: 8
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 4
                Ui.Label {
                    objectName: "settingsProfileName"
                    text: settings.service.profile
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    font.pixelSize: 11
                }
                Ui.Label {
                    objectName: "settingsProfileStatus"
                    text: settings.service.profileSettings.dirty ? "Unsaved" : "Saved"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    font.pixelSize: 10
                    color: settings.service.profileSettings.dirty ? Ui.Theme.paper : Ui.Theme.muted
                    Accessible.name: settings.service.profile + ": " + text
                }
            }
            Ui.ActionButton { objectName: "revertProfile"; text: "Revert"; font.pixelSize: 11; enabled: settings.service.profileSettings.dirty; onClicked: settings.service.profileSettings.revert() }
            Ui.ActionButton { objectName: "saveProfile"; text: "Save"; font.pixelSize: 11; checked: enabled; enabled: settings.service.profileSettings.dirty; onClicked: settings.service.profileSettings.save() }
        }
    }
}
