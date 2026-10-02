import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact

    hoverEnabled: true
    onClicked: root.expanded = !root.expanded

    Kirigami.Icon {
        id: icon
        anchors.fill: parent
        source: root.iconPath
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
}
