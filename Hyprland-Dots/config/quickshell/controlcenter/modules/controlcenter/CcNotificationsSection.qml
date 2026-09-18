import QtQuick
import QtQuick.Layouts
import "root:/modules/controlcenter"
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"

/** Scrollable list of the notifications QuickShell currently tracks. */
Item {
    id: root

    readonly property int itemCount: list.count

    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.notificationSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            StyledText {
                Layout.fillWidth: true
                text: "Notifications"
                color: Theme.textPrimary
                font.pixelSize: Appearance.font.pixelSize.textBase
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                visible: root.itemCount > 0
                text: root.itemCount
                color: Theme.textDim
                font.pixelSize: Appearance.font.pixelSize.textSmall
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(
                Math.max(0, count * (Theme.notificationItemHeight + Theme.notificationSpacing) - Theme.notificationSpacing),
                Theme.notificationMaxHeight)
            visible: count > 0
            clip: true
            spacing: Theme.notificationSpacing
            boundsBehavior: Flickable.StopAtBounds
            model: CcNotifications.model

            delegate: CcNotificationItem {
                width: list.width
                notification: CcNotifications.at(index)
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: list.count === 0
            text: CcNotifications.emptyMessage
            color: Theme.textDim
            font.pixelSize: Appearance.font.pixelSize.textSmall
            wrapMode: Text.WordWrap
        }
    }
}
