import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "root:/modules/controlcenter"
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"

/** Avatar, user name, uptime, and the four header actions. */
Item {
    id: header

    property bool powerMenuOpen: false

    signal lockRequested()
    signal powerRequested()
    signal settingsRequested()
    signal editRequested()
    signal closeRequested()

    implicitHeight: Theme.avatarSize

    RowLayout {
        anchors.fill: parent
        spacing: Theme.headerSpacing

        // ── Avatar: ~/.face when present, monogram otherwise ──────────────
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.avatarSize
            implicitHeight: Theme.avatarSize

            Rectangle {
                anchors.fill: parent
                radius: Theme.avatarRadius
                color: Theme.tileIconBg
                border.width: 1
                border.color: Theme.tileBorder
            }

            Image {
                id: avatarImage
                anchors.fill: parent
                source: CcSystem.avatarAvailable ? "file://" + Theme.avatarImagePath : ""
                sourceSize.width: Theme.avatarSize * 2
                sourceSize.height: Theme.avatarSize * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                layer.enabled: status === Image.Ready
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: avatarImage.width
                        height: avatarImage.height
                        radius: Theme.avatarRadius
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: avatarImage.status !== Image.Ready
                text: (CcSystem.userName || "?").charAt(0).toUpperCase()
                color: Theme.accent
                font.pixelSize: Appearance.font.pixelSize.textLarge
                font.weight: Font.DemiBold
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: CcSystem.userName
                color: Theme.textPrimary
                font.pixelSize: Appearance.font.pixelSize.textMedium
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            StyledText {
                Layout.fillWidth: true
                text: CcSystem.uptimeText
                color: Theme.textDim
                font.pixelSize: Appearance.font.pixelSize.textSmall
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.headerButtonSpacing

            CcIconButton {
                iconName: "lock"
                onClicked: header.lockRequested()
            }
            CcIconButton {
                id: powerButton
                iconName: "power_settings_new"
                toggled: header.powerMenuOpen
                onClicked: header.powerRequested()
            }
            CcIconButton {
                iconName: "settings"
                onClicked: header.settingsRequested()
            }
            CcIconButton {
                iconName: "edit"
                onClicked: header.editRequested()
            }
            CcIconButton {
                iconName: "close"
                onClicked: header.closeRequested()
            }
        }
    }
}
