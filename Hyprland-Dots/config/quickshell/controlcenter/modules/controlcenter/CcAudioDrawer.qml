pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/modules/controlcenter"
import "root:/services"

/**
 * Audio device drawer — shared by the control center panel and the standalone
 * "audiocenter" panel.
 *
 * Header (pavucontrol button) plus the list of output devices (active one
 * first) and input devices, and the volume / mute of the active output.
 * Clicking a row makes that device the default.
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
                text: "volume_up"
                iconSize: 22
                color: Theme.accent
                font.family: Theme.iconFontFamily
            }

            StyledText {
                Layout.fillWidth: true
                text: "Dispositivos de audio"
                color: Theme.textPrimary
                font.pixelSize: Appearance.font.pixelSize.textMedium
                font.weight: Font.Bold
            }

            // Open pavucontrol (Output Devices tab) — same fallback spirit as
            // the Bluetooth drawer's Blueman button
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
                    onClicked: CcSystem.runDetached(["pavucontrol", "-t", "3"])
                }
            }
        }

        // ── Output devices ────────────────────────────────────────────────
        StyledText {
            text: "SALIDAS"
            color: Theme.textDim
            font.pixelSize: Appearance.font.pixelSize.textSmall - 1
            font.weight: Font.Bold
        }

        Repeater {
            model: CcSystem.audioSinks

            delegate: CcAudioRow {
                required property var modelData

                Layout.fillWidth: true
                node: modelData
                active: CcSystem.audioSink === modelData
                trailing: (CcSystem.audioSink === modelData) ? CcSystem.volumePercentText : ""
                onActivated: CcSystem.setDefaultSink(modelData)
            }
        }

        StyledText {
            visible: (CcSystem.audioSinks ?? []).length === 0
            text: "No hay dispositivos de salida."
            color: Theme.textDim
            font.pixelSize: Appearance.font.pixelSize.textSmall
        }

        // ── Volume / mute of the active output ────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            CcSlider {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                icon: CcSystem.volumeIcon
                value: CcSystem.volume
                fillColor: CcSystem.volumeMuted ? Theme.trackDim : Theme.accent
                onMoved: (value) => CcSystem.setVolume(value)
            }

            Rectangle {
                width: 30
                height: 30
                radius: 15
                color: muteHover.hovered ? Theme.tileHoverBg : Theme.tileIconBg
                border.width: 1
                border.color: CcSystem.volumeMuted ? Theme.accent : Theme.tileBorder

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: CcSystem.volumeMuted ? "volume_off" : "volume_up"
                    iconSize: 17
                    color: CcSystem.volumeMuted ? Theme.accent : Theme.textPrimary
                    font.family: Theme.iconFontFamily
                }

                HoverHandler { id: muteHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CcSystem.toggleMute()
                }
            }
        }

        // ── Input devices ─────────────────────────────────────────────────
        StyledText {
            text: "ENTRADAS"
            color: Theme.textDim
            font.pixelSize: Appearance.font.pixelSize.textSmall - 1
            font.weight: Font.Bold
        }

        Repeater {
            model: CcSystem.audioSources

            delegate: CcAudioRow {
                required property var modelData

                Layout.fillWidth: true
                node: modelData
                active: CcSystem.audioSource === modelData
                onActivated: CcSystem.setDefaultSource(modelData)
            }
        }

        StyledText {
            visible: (CcSystem.audioSources ?? []).length === 0
            text: "No hay dispositivos de entrada."
            color: Theme.textDim
            font.pixelSize: Appearance.font.pixelSize.textSmall
        }
    }
}
