import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "Lockouts.js" as Lockouts

PlasmaExtras.Representation {
    id: full

    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 14
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: Kirigami.Units.gridUnit * 26

    collapseMarginsHint: true

    // Class colours by class ID, which doesn't depend on the API locale.
    readonly property var classColors: ({
        1: "#c69b6d", 2: "#f48cba", 3: "#aad372", 4: "#fff468", 5: "#ffffff", 6: "#c41e3a", 7: "#0070dd",
        8: "#3fc7eb", 9: "#8788ee", 10: "#00ff98", 11: "#ff7c0a", 12: "#a330c9", 13: "#33937f"
    })

    function configure() {
        Plasmoid.internalAction("configure").trigger()
    }

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                elide: Text.ElideRight
                text: i18n("Raid Lockouts")
            }
            PlasmaComponents.Label {
                font.features: { "tnum": 1 }
                opacity: 0.7
                text: i18n("Resets in %1", root.resetCountdown)
                PlasmaComponents.ToolTip {
                    text: i18n("Weekly reset %1", Qt.formatDateTime(new Date(root.nextReset), "dddd hh:mm"))
                }
                HoverHandler {}
            }
            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                enabled: root.configured && !root.loading
                onClicked: root.refresh(false)
                PlasmaComponents.ToolTip { text: i18n("Refresh") }
            }
            PlasmaComponents.ToolButton {
                icon.name: "configure"
                onClicked: full.configure()
                PlasmaComponents.ToolTip { text: i18n("Configure…") }
            }
        }
    }

    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: !root.configured || root.characters.length === 0
        iconName: root.iconPath
        text: !root.configured ? i18n("Connect to Battle.net") : i18n("No characters yet")
        explanation: !root.configured
            ? i18n("Create a free API client at develop.battle.net and paste its ID and secret into the settings.")
            : i18n("Add your characters as Name-Realm, one per line.")
        helpfulAction: Kirigami.Action {
            icon.name: "configure"
            text: i18n("Configure…")
            onTriggered: full.configure()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: root.configured && root.characters.length > 0

        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                clip: true
                model: root.view
                spacing: Kirigami.Units.largeSpacing

                delegate: ColumnLayout {
                    id: character
                    required property var modelData
                    width: list.width
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.largeSpacing
                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.largeSpacing

                        Rectangle {
                            width: 4
                            radius: 2
                            Layout.fillHeight: true
                            color: character.modelData.summary
                                ? (full.classColors[character.modelData.summary.classId] || Kirigami.Theme.textColor)
                                : Qt.alpha(Kirigami.Theme.textColor, 0.3)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Kirigami.Heading {
                                Layout.fillWidth: true
                                level: 4
                                elide: Text.ElideRight
                                text: character.modelData.name
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                                elide: Text.ElideRight
                                text: {
                                    var s = character.modelData.summary
                                    return [
                                        s ? i18n("Level %1 %2", s.level, s.className) : "",
                                        character.modelData.realm,
                                        s && s.lastLogin ? i18n("last login %1 ago", Lockouts.formatCountdown(root.now - s.lastLogin)) : ""
                                    ].filter(t => t !== "").join(" · ")
                                }
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        visible: character.modelData.error !== ""
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.negativeTextColor
                        text: errors.text(character.modelData.error)
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        visible: character.modelData.lockouts.length === 0 && character.modelData.error === ""
                        opacity: 0.6
                        text: i18n("Not saved to anything this week")
                    }

                    Repeater {
                        model: character.modelData.lockouts
                        delegate: LockoutRow {
                            required property var modelData
                            lockout: modelData
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            horizontalAlignment: Text.AlignHCenter
            font: Kirigami.Theme.smallFont
            wrapMode: Text.WordWrap
            color: root.errorMsg ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            opacity: root.errorMsg ? 1 : 0.6
            text: root.errorMsg
                ? root.errorMsg
                : root.loading
                    ? i18n("Loading…")
                    : (isNaN(root.lastUpdated.getTime()) ? "" : i18n("Updated %1. ", Qt.formatTime(root.lastUpdated, Qt.DefaultLocaleShortDate)))
                      + i18n("Battle.net updates a character after you log out.")
        }
    }

    ErrorText { id: errors }
}
