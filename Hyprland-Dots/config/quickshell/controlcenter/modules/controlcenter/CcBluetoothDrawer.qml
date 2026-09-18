import QtQuick
import QtQuick.Layouts
import "root:/modules/controlcenter"
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"

/**
 * Expandable Bluetooth device management drawer.
 * Displays paired/saved devices, connection status, device actions,
 * scan for nearby devices, and power toggle.
 */
Rectangle {
    id: root

    implicitHeight: contentCol.implicitHeight + 24
    radius: Theme.tileRadius
    color: Theme.tileBg
    border.width: 1
    border.color: Theme.tileBorder
    clip: true

    function getDeviceIcon(name) {
        const lower = (name ?? "").toLowerCase()
        if (lower.includes("jbl") || lower.includes("beam") || lower.includes("headphone")
            || lower.includes("buds") || lower.includes("airpod") || lower.includes("ear") || lower.includes("steren"))
            return "headphones"
        if (lower.includes("speaker") || lower.includes("sound") || lower.includes("party") || lower.includes("audio"))
            return "speaker"
        return "bluetooth"
    }

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
                text: CcSystem.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
                iconSize: 22
                color: CcSystem.bluetoothEnabled ? Theme.accent : Theme.textDim
                font.family: Theme.iconFontFamily
            }

            StyledText {
                Layout.fillWidth: true
                text: "Dispositivos Bluetooth"
                color: Theme.textPrimary
                font.pixelSize: Appearance.font.pixelSize.textMedium
                font.weight: Font.Bold
            }

            // Scan / Refresh button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: scanHover.hovered ? Theme.tileHoverBg : "transparent"
                visible: CcSystem.bluetoothEnabled

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 18
                    color: CcSystem.bluetoothScanning ? Theme.accent : Theme.textPrimary
                    font.family: Theme.iconFontFamily
                }

                HoverHandler { id: scanHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CcSystem.scanBluetooth()
                }
            }

            // Open Blueman Settings button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: setHover.hovered ? Theme.tileHoverBg : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "settings"
                    iconSize: 18
                    color: Theme.textPrimary
                    font.family: Theme.iconFontFamily
                }

                HoverHandler { id: setHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CcSystem.runDetached(["blueman-manager"])
                }
            }

            // Power Switch Button
            Rectangle {
                width: 60
                height: 26
                radius: 13
                color: CcSystem.bluetoothEnabled ? Theme.accent : Theme.tileIconBg
                border.width: 1
                border.color: Theme.tileBorder

                StyledText {
                    anchors.centerIn: parent
                    text: CcSystem.bluetoothEnabled ? "ON" : "OFF"
                    color: CcSystem.bluetoothEnabled ? Theme.onAccent : Theme.textDim
                    font.pixelSize: Appearance.font.pixelSize.textSmall
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CcSystem.toggleBluetooth()
                }
            }
        }

        // ── Content when Bluetooth is ON ──────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: CcSystem.bluetoothEnabled

            // Section Label: Paired Devices
            StyledText {
                text: "DISPOSITIVOS GUARDADOS"
                color: Theme.textDim
                font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                font.weight: Font.Bold
            }

            // Paired Devices List
            Repeater {
                model: CcSystem.bluetoothPairedDevices

                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 10
                    color: devHover.hovered ? Theme.tileHoverBg : Theme.tileIconBg
                    border.width: 1
                    border.color: modelData.connected ? Theme.accent : Theme.tileBorder

                    HoverHandler { id: devHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        MaterialSymbol {
                            text: root.getDeviceIcon(modelData.name)
                            iconSize: 20
                            color: modelData.connected ? Theme.accent : Theme.textPrimary
                            font.family: Theme.iconFontFamily
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
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
                                    color: modelData.connected ? "#4ade80" : Theme.textDim
                                }
                                StyledText {
                                    text: modelData.connected ? "Conectado" : "Guardado"
                                    color: modelData.connected ? "#4ade80" : Theme.textDim
                                    font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                                }
                            }
                        }

                        // Connect / Disconnect button
                        Rectangle {
                            implicitWidth: 86
                            implicitHeight: 28
                            radius: 14
                            color: modelData.connected ? "#ef4444" : Theme.accent

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.connected ? "Desconectar" : "Conectar"
                                color: modelData.connected ? "#ffffff" : Theme.onAccent
                                font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.connected) {
                                        CcSystem.disconnectBluetooth(modelData.mac)
                                    } else {
                                        CcSystem.connectBluetooth(modelData.mac)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // If no paired devices
            StyledText {
                visible: (CcSystem.bluetoothPairedDevices ?? []).length === 0
                text: "No hay dispositivos vinculados guardados."
                color: Theme.textDim
                font.pixelSize: Appearance.font.pixelSize.textSmall
            }

            // Section Label: Available / Scanned Devices
            Item { Layout.preferredHeight: 4 }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: CcSystem.bluetoothScanning ? "BUSCANDO DISPOSITIVOS CERCANOS…" : "DISPOSITIVOS DISPONIBLES"
                    color: CcSystem.bluetoothScanning ? Theme.accent : Theme.textDim
                    font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                    font.weight: Font.Bold
                }

                // Scan trigger button
                Rectangle {
                    implicitWidth: 70
                    implicitHeight: 22
                    radius: 11
                    color: Theme.tileIconBg
                    border.width: 1
                    border.color: Theme.tileBorder
                    visible: !CcSystem.bluetoothScanning

                    StyledText {
                        anchors.centerIn: parent
                        text: "Buscar"
                        color: Theme.textPrimary
                        font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: CcSystem.scanBluetooth()
                    }
                }
            }

            // Available Devices List
            Repeater {
                model: CcSystem.bluetoothAvailableDevices

                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: Theme.tileIconBg
                    border.width: 1
                    border.color: Theme.tileBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        MaterialSymbol {
                            text: "bluetooth"
                            iconSize: 18
                            color: Theme.textDim
                            font.family: Theme.iconFontFamily
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Theme.textPrimary
                            font.pixelSize: Appearance.font.pixelSize.textSmall
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            implicitWidth: 64
                            implicitHeight: 24
                            radius: 12
                            color: Theme.accent

                            StyledText {
                                anchors.centerIn: parent
                                text: "Vincular"
                                color: Theme.onAccent
                                font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CcSystem.pairBluetooth(modelData.mac)
                            }
                        }
                    }
                }
            }
        }

        // ── Content when Bluetooth is OFF ─────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 10
            color: Theme.tileIconBg
            visible: !CcSystem.bluetoothEnabled

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    text: "bluetooth_disabled"
                    iconSize: 20
                    color: Theme.textDim
                    font.family: Theme.iconFontFamily
                }

                StyledText {
                    text: "El Bluetooth está desactivado. Haz clic para encenderlo."
                    color: Theme.textDim
                    font.pixelSize: Appearance.font.pixelSize.textSmall
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: CcSystem.toggleBluetooth()
            }
        }
    }
}
