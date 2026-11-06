import QtQuick
import QtQuick.Layouts
import "root:/modules/controlcenter"
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"

/**
 * Expandable Bluetooth device management drawer — Frosted Glass Chicklets Style.
 * Harmonized with Waybar Oglo Chicklets aesthetic and Wallust dynamic palette.
 */
Item {
    id: root

    implicitHeight: contentCol.implicitHeight + 12

    function getDeviceIcon(name) {
        const lower = (name ?? "").toLowerCase()
        if (lower.includes("mouse") || lower.includes("ratón") || lower.includes("raton")
            || lower.includes("steren") || lower.includes("com-5890"))
            return "mouse"
        if (lower.includes("jbl") || lower.includes("beam") || lower.includes("headphone")
            || lower.includes("buds") || lower.includes("airpod") || lower.includes("ear")
            || lower.includes("diadema") || lower.includes("bt20"))
            return "headphones"
        if (lower.includes("speaker") || lower.includes("sound") || lower.includes("party")
            || lower.includes("audio") || lower.includes("parlante"))
            return "speaker"
        if (lower.includes("phone") || lower.includes("teléfono") || lower.includes("telefono")
            || lower.includes("k1ev3r") || lower.includes("galaxy") || lower.includes("iphone"))
            return "smartphone"
        if (lower.includes("watch") || lower.includes("reloj"))
            return "watch"
        if (lower.includes("tv") || lower.includes("box") || lower.includes("claro"))
            return "tv"
        return "bluetooth"
    }

    ColumnLayout {
        id: contentCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        // ── Header (Waybar Chicklet Style) ────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: CcSystem.bluetoothEnabled ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: CcSystem.bluetoothEnabled ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : Theme.tileBorder

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: CcSystem.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
                    iconSize: 20
                    color: CcSystem.bluetoothEnabled ? Theme.accentText : Theme.textDim
                    font.family: Theme.iconFontFamily
                }
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
                width: 30
                height: 30
                radius: 15
                color: scanHover.hovered ? Theme.tileHoverBg : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Theme.tileBorder
                visible: CcSystem.bluetoothEnabled

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 18
                    color: CcSystem.bluetoothScanning ? Theme.accentText : Theme.textPrimary
                    font.family: Theme.iconFontFamily
                }

                HoverHandler { id: scanHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CcSystem.scanBluetooth()
                }
            }

            // Power Switch Button (Pill chicklet)
            Rectangle {
                width: 62
                height: 28
                radius: 14
                color: CcSystem.bluetoothEnabled ? Theme.accent : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: CcSystem.bluetoothEnabled ? Theme.accent : Theme.tileBorder

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
                text: "DISPOSITIVOS VINCULADOS"
                color: Theme.textDim
                font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                font.weight: Font.Bold
            }

            // Paired Devices List (Chicklets)
            Repeater {
                model: CcSystem.bluetoothPairedDevices

                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: 14
                    color: devHover.hovered 
                        ? (modelData.connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Theme.tileHoverBg)
                        : (modelData.connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                    border.width: 1
                    border.color: modelData.connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.50) : Theme.tileBorder

                    HoverHandler { id: devHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 12

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: modelData.connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.getDeviceIcon(modelData.name)
                                iconSize: 18
                                color: modelData.connected ? Theme.accentText : Theme.textPrimary
                                font.family: Theme.iconFontFamily
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.textPrimary
                                font.pixelSize: Appearance.font.pixelSize.textMedium
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: 5
                                Rectangle {
                                    width: 7
                                    height: 7
                                    radius: 3.5
                                    color: modelData.connected ? "#4ade80" : Theme.textDim
                                }
                                StyledText {
                                    text: modelData.connected ? "Conectado" : "Guardado"
                                    color: modelData.connected ? "#4ade80" : Theme.textDim
                                    font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                                }
                            }
                        }

                        // Connect / Disconnect button (Frosted Glass Chicklet)
                        Rectangle {
                            implicitWidth: 92
                            implicitHeight: 28
                            radius: 14
                            color: modelData.connected ? Qt.rgba(0.92, 0.26, 0.26, 0.85) : Theme.accent
                            border.width: 1
                            border.color: modelData.connected ? "#ef4444" : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.60)

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
                    color: CcSystem.bluetoothScanning ? Theme.accentText : Theme.textDim
                    font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                    font.weight: Font.Bold
                }

                // Scan trigger button
                Rectangle {
                    implicitWidth: 72
                    implicitHeight: 24
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.10)
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
                    implicitHeight: 44
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Theme.tileBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 10

                        MaterialSymbol {
                            text: root.getDeviceIcon(modelData.name)
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
                            implicitWidth: 72
                            implicitHeight: 26
                            radius: 13
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
            implicitHeight: 52
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: Theme.tileBorder
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
