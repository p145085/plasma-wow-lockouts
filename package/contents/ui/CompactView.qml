import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool showText: Plasmoid.configuration.showCountdownInPanel && !vertical

    Layout.minimumWidth: vertical ? -1 : row.implicitWidth
    Layout.preferredWidth: Layout.minimumWidth

    hoverEnabled: true
    onClicked: root.expanded = !root.expanded

    RowLayout {
        id: row
        anchors.centerIn: parent
        height: parent.height
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            id: icon
            source: root.iconPath
            Layout.preferredHeight: Math.min(compact.height, Kirigami.Units.iconSizes.medium)
            Layout.preferredWidth: Layout.preferredHeight
            Layout.alignment: Qt.AlignVCenter
            opacity: root.configured ? 1 : 0.5

            // Number of instances saved to this week.
            Rectangle {
                visible: Plasmoid.configuration.showCountInPanel && root.lockoutCount > 0
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.max(Math.round(icon.paintedHeight * 0.5), count.implicitHeight)
                width: Math.max(height, count.implicitWidth + 4)
                radius: height / 2
                color: Kirigami.Theme.highlightColor
                border.color: Kirigami.Theme.backgroundColor
                border.width: 1

                Text {
                    id: count
                    anchors.centerIn: parent
                    text: root.lockoutCount
                    color: Kirigami.Theme.highlightedTextColor
                    font.pixelSize: Math.max(8, Math.round(icon.paintedHeight * 0.36))
                    font.bold: true
                }
            }
        }

        PlasmaComponents.Label {
            visible: compact.showText
            text: root.resetCountdown
            font.features: { "tnum": 1 }
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: Kirigami.Units.smallSpacing
        }
    }
}
