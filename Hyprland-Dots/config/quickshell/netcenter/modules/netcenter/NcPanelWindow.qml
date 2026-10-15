import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/modules/controlcenter"
import "root:/modules/netcenter"

/**
 * Standalone Wi-Fi panel: the same glass card as the control center, with the
 * shared Wi-Fi drawer (`CcWifiDrawer`) as its body.
 *
 * Opened from the waybar network module with
 * `qs -c netcenter ipc call panel toggle`.
 */
PanelWindow {
    id: panel

    /** The screen this instance is drawn on, injected by `Variants`. */
    required property var modelData

    screen: panel.modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property bool isTargetScreen: panel.screen !== null && panel.screen.name === NcPanelState.openScreenName

    visible: NcPanelState.visible && isTargetScreen
    color: "transparent"
    exclusiveZone: 0
    aboveWindows: true
    WlrLayershell.namespace: "quickshell-netcenter"
    WlrLayershell.layer: WlrLayer.Overlay

    WlrLayershell.keyboardFocus: (NcPanelState.visible && isTargetScreen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ── Click-away dismissal: clicking anywhere outside the card closes the panel ──
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: NcPanelState.dismiss()
    }

    // ── Keyboard shortcut: Escape always closes the panel regardless of child focus ──
    Shortcut {
        sequence: "Escape"
        enabled: panel.visible
        onActivated: NcPanelState.dismiss()
    }

    // ── Floating card (same glass spec as the control center) ─────────────
    Rectangle {
        id: card
        z: 1
        width: Theme.panelWidth
        height: content.implicitHeight + Theme.panelPadding * 2
        anchors.top: parent.top
        anchors.topMargin: Theme.panelMargin
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 20
        color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.30)
        clip: true

        // Specular Top Highlight line
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: Qt.rgba(1, 1, 1, 0.80) }
                GradientStop { position: 0.8; color: Qt.rgba(1, 1, 1, 0.80) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ── Content ───────────────────────────────────────────────────────
        Column {
            id: content
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.panelPadding

            CcWifiDrawer {
                width: parent.width
            }
        }
    }
}
