import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/modules/controlcenter"

/**
 * Standalone center panel window: the same glass card as the control center.
 * The panel body is declared by the config and lands inside the card, e.g.
 *
 *     CcCenterPanelWindow {
 *         panelState: panel
 *         panelName: "netcenter"
 *         CcWifiDrawer { width: parent.width }
 *     }
 *
 * One instance is created per output by the config's `shell.qml`; visibility
 * is decided by the shared `panelState` (see CcCenterPanelState).
 */
PanelWindow {
    id: panel

    /** The screen this instance is drawn on, injected by `Variants`. */
    required property var modelData

    /** The CcCenterPanelState instance this window belongs to. */
    required property var panelState

    /** Short name of the panel, used for the layer namespace
     *  ("quickshell-netcenter", matching the Hyprland blur layer rules). */
    property string panelName: "center"

    /** The body: everything declared inside the instance is added here. */
    default property alias body: content.data

    screen: panel.modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property bool isTargetScreen: panel.screen !== null && panel.screen.name === panel.panelState.openScreenName

    visible: panel.panelState.visible && isTargetScreen
    color: "transparent"
    exclusiveZone: 0
    aboveWindows: true
    WlrLayershell.namespace: "quickshell-" + panel.panelName
    WlrLayershell.layer: WlrLayer.Overlay

    WlrLayershell.keyboardFocus: (panel.panelState.visible && isTargetScreen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ── Click-away dismissal: clicking anywhere outside the card closes the panel ──
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: panel.panelState.dismiss()
    }

    // ── Keyboard shortcut: Escape always closes the panel regardless of child focus ──
    Shortcut {
        sequence: "Escape"
        enabled: panel.visible
        onActivated: panel.panelState.dismiss()
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

        // ── Content (the config's body lands here) ────────────────────────
        Column {
            id: content
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.panelPadding
        }
    }
}
