import QtQuick
import QtQuick.Layouts
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/modules/controlcenter"
import "root:/services"

/**
 * One Wi-Fi network row inside the Wi-Fi drawer.
 *
 * Left: icon, SSID and state ("Conectado" / "Conectando…" / "Guardada" /
 * "Protegida" / "Abierta"). Right: signal percentage, a lock for secured
 * networks and, on the connected network, a "Desconectar" button.
 *
 * Clicking any other row starts the connection; networks without saved
 * credentials go through the inline password prompt instead.
 */
Rectangle {
    id: root

    /** The WifiNetwork this row shows (an element of WifiService.networks). */
    required property var network

    /** Emitted when the row is clicked and a connection should start. */
    signal connectRequested(var network)

    readonly property bool connected: root.network?.connected ?? false
    readonly property bool secured: !WifiService.isOpen(root.network)
    readonly property bool busy: WifiService.connecting && WifiService.pendingNetwork === root.network
    readonly property bool promptForThis: WifiService.prompting && WifiService.pendingNetwork === root.network

    implicitHeight: 46
    radius: 10
    color: (rowHover.hovered && !root.connected) || root.promptForThis ? Theme.tileHoverBg : Theme.tileIconBg
    border.width: 1
    border.color: root.connected ? Theme.accent : Theme.tileBorder

    HoverHandler {
        id: rowHover
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.connected && !root.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: root.connectRequested(root.network)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        MaterialSymbol {
            text: "wifi"
            iconSize: 20
            color: root.connected ? Theme.accent : Theme.textPrimary
            font.family: Theme.iconFontFamily
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.network?.name ?? ""
                color: Theme.textPrimary
                font.pixelSize: Appearance.font.pixelSize.textMedium
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 4

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: root.connected ? "#4ade80" : Theme.textDim
                }

                StyledText {
                    text: root.connected ? "Conectado"
                        : root.busy ? "Conectando…"
                        : root.promptForThis ? "Esperando contraseña"
                        : root.network?.known ? "Guardada"
                        : root.secured ? "Protegida"
                        : "Abierta"
                    color: root.connected ? "#4ade80"
                        : root.busy ? Theme.accent
                        : Theme.textDim
                    font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                }
            }
        }

        // Connection in progress: spinning refresh icon
        MaterialSymbol {
            visible: root.busy
            text: "refresh"
            iconSize: 18
            color: Theme.accent
            font.family: Theme.iconFontFamily

            RotationAnimator on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 1100
                loops: Animation.Infinite
            }
        }

        // Signal strength
        StyledText {
            visible: !root.busy
            text: WifiService.signalPercent(root.network) + "%"
            color: Theme.textDim
            font.pixelSize: Appearance.font.pixelSize.textSmall
        }

        // Lock for password-protected networks
        MaterialSymbol {
            visible: !root.busy && root.secured
            text: "lock"
            iconSize: 15
            color: Theme.textDim
            font.family: Theme.iconFontFamily
        }

        // Disconnect button on the connected row
        Rectangle {
            visible: root.connected
            implicitWidth: 86
            implicitHeight: 28
            radius: 14
            color: "#ef4444"

            StyledText {
                anchors.centerIn: parent
                text: "Desconectar"
                color: "#ffffff"
                font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                font.weight: Font.Bold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.network?.disconnect()
            }
        }
    }
}
