import QtQuick
import QtQuick.Layouts
import "root:/modules/controlcenter"
import "root:/modules/common"
import "root:/modules/common/widgets"

/** Single notification row: app name, summary, body, dismiss button. */
Item {
    id: root

    property var notification: null

    implicitHeight: Theme.notificationItemHeight
    readonly property bool hovered: mouse.containsMouse

    Rectangle {
        anchors.fill: parent
        radius: Theme.notificationRadius
        color: root.hovered ? Theme.tileBgHover : Theme.tileBg
        border.width: 1
        border.color: Theme.tileBorder

        Behavior on color {
            ColorAnimation { duration: Theme.colorDuration }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        anchors.topMargin: 7
        anchors.bottomMargin: 7
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            StyledText {
                text: root.notification?.appName ?? ""
                visible: text.length > 0
                color: Theme.accent
                font.pixelSize: Appearance.font.pixelSize.textSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.preferredWidth: Theme.notificationMaxAppWidth
            }

            StyledText {
                Layout.fillWidth: true
                text: root.notification?.summary ?? ""
                color: Theme.textPrimary
                font.pixelSize: Appearance.font.pixelSize.textSmall
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            CcIconButton {
                id: dismissButton
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.notificationDismissSize
                implicitHeight: Theme.notificationDismissSize
                iconName: "close"
                iconColor: Theme.textDim
                onClicked: {
                    const notification = root.notification
                    if (notification)
                        notification.dismiss()
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.notification?.body ?? ""
            visible: text.length > 0
            color: Theme.textDim
            font.pixelSize: Appearance.font.pixelSize.textSmall
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: Theme.notificationBodyLines
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
