import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// One saved instance; click to list the bosses killed this week.
PlasmaComponents.ItemDelegate {
    id: row

    required property var lockout
    property bool expanded: false

    // Item quality colours: LFR green, Normal blue, Heroic purple, Mythic orange.
    readonly property color tierColor: {
        var t = lockout.difficultyType
        if (t.indexOf("MYTHIC") >= 0) return "#ff8000"
        if (t.indexOf("HEROIC") >= 0) return "#a335ee"
        if (t === "LFR") return "#1eff00"
        return "#0070dd"
    }

    hoverEnabled: true
    onClicked: expanded = !expanded

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: row.expanded ? "arrow-down" : "arrow-right"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                opacity: 0.6
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: row.lockout.instance
            }
            Rectangle {
                implicitWidth: chip.implicitWidth + Kirigami.Units.smallSpacing * 3
                implicitHeight: chip.implicitHeight + 2
                radius: height / 2
                color: Qt.alpha(row.tierColor, 0.18)
                border.color: row.tierColor
                border.width: 1
                PlasmaComponents.Label {
                    id: chip
                    anchors.centerIn: parent
                    font: Kirigami.Theme.smallFont
                    text: row.lockout.difficulty
                }
            }
            PlasmaComponents.Label {
                Layout.minimumWidth: Kirigami.Units.gridUnit * 2
                horizontalAlignment: Text.AlignRight
                font.features: { "tnum": 1 }
                font.bold: row.lockout.cleared
                color: row.lockout.cleared ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                text: row.lockout.cleared ? i18n("Cleared")
                    : row.lockout.total > 0 ? row.lockout.killed + "/" + row.lockout.total : row.lockout.killed
            }
        }

        Rectangle {
            visible: row.lockout.total > 0
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
            implicitHeight: 3
            radius: 1.5
            color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
            Rectangle {
                width: parent.width * Math.min(1, row.lockout.killed / Math.max(1, row.lockout.total))
                height: parent.height
                radius: parent.radius
                color: row.tierColor
            }
        }

        Repeater {
            model: row.expanded ? row.lockout.kills : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    text: "✓ " + modelData.name
                }
                PlasmaComponents.Label {
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    text: Qt.formatDateTime(new Date(modelData.t), "ddd hh:mm")
                }
            }
        }
    }
}
