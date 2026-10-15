pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/modules/controlcenter"
import "root:/services"

/**
 * Wi-Fi management drawer — shared by the control center panel and the
 * standalone "netcenter" panel.
 *
 * Header (status icon, title, rescan and on/off switch) plus either the
 * inline password prompt or the list of visible networks (connected first).
 * Saved and open networks connect on the row click; protected unknown
 * networks open the password prompt instead.
 */
Rectangle {
    id: root

    implicitHeight: contentCol.implicitHeight + 24
    radius: Theme.tileRadius
    color: Theme.tileBg
    border.width: 1
    border.color: Theme.tileBorder
    clip: true

    ColumnLayout {
        id: contentCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        spacing: 10

        // ── Header ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: WifiService.wifiEnabled ? "wifi" : "wifi_off"
                iconSize: 22
                color: WifiService.wifiEnabled ? Theme.accent : Theme.textDim
                font.family: Theme.iconFontFamily
            }

            StyledText {
                Layout.fillWidth: true
                text: "Redes WiFi"
                color: Theme.textPrimary
                font.pixelSize: Appearance.font.pixelSize.textMedium
                font.weight: Font.Bold
            }

            // Rescan button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                visible: WifiService.wifiEnabled
                color: scanHover.hovered ? Theme.tileHoverBg : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 18
                    color: WifiService.connecting ? Theme.accent : Theme.textPrimary
                    font.family: Theme.iconFontFamily
                }

                HoverHandler { id: scanHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WifiService.refreshScan()
                }
            }

            // Power switch
            Rectangle {
                width: 60
                height: 26
                radius: 13
                color: WifiService.wifiEnabled ? Theme.accent : Theme.tileIconBg
                border.width: 1
                border.color: Theme.tileBorder

                StyledText {
                    anchors.centerIn: parent
                    text: WifiService.wifiEnabled ? "ON" : "OFF"
                    color: WifiService.wifiEnabled ? Theme.onAccent : Theme.textDim
                    font.pixelSize: Appearance.font.pixelSize.textSmall
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WifiService.toggleWifi()
                }
            }
        }

        // ── WiFi disabled ─────────────────────────────────────────────────
        StyledText {
            visible: !WifiService.wifiEnabled
            Layout.fillWidth: true
            text: "WiFi apagado. Activalo para ver las redes disponibles."
            color: Theme.textDim
            font.pixelSize: Appearance.font.pixelSize.textSmall
            wrapMode: Text.Wrap
        }

        // ── Password prompt ───────────────────────────────────────────────
        CcWifiPasswordPrompt {
            Layout.fillWidth: true
            visible: WifiService.wifiEnabled && WifiService.prompting
        }

        // ── Network list ──────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: WifiService.wifiEnabled && !WifiService.prompting

            StyledText {
                text: "REDES DISPONIBLES"
                color: Theme.textDim
                font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                font.weight: Font.Bold
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(list.contentHeight, 280)

                model: WifiService.networks
                spacing: 8
                clip: true
                interactive: list.contentHeight > list.height

                delegate: CcWifiRow {
                    required property var modelData

                    width: list.width
                    network: modelData
                    onConnectRequested: WifiService.requestConnect(network)
                }
            }

            StyledText {
                visible: (WifiService.networks ?? []).length === 0
                text: "Buscando redes…"
                color: Theme.textDim
                font.pixelSize: Appearance.font.pixelSize.textSmall
            }
        }

        // ── Errors that do not belong to the prompt ───────────────────────
        StyledText {
            visible: WifiService.errorText !== "" && !WifiService.prompting
            Layout.fillWidth: true
            text: WifiService.errorText
            color: "#ef4444"
            font.pixelSize: Appearance.font.pixelSize.textSmall
            wrapMode: Text.Wrap
        }
    }
}
