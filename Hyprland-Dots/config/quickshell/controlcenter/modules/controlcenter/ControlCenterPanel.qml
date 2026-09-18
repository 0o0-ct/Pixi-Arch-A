import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/modules/controlcenter"
import "root:/services"

/**
 * Control center: a 420px panel anchored to the top of one screen and centred
 * horizontally on it.
 *
 * Layout, top to bottom: header (avatar / user / uptime + actions), the
 * brightness & volume sliders, the 2-column tile grid, the notification list,
 * and the inline power menu when it is open.
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

    readonly property bool isTargetScreen: panel.screen !== null && panel.screen.name === CcPanelState.openScreenName

    visible: CcPanelState.visible && isTargetScreen
    color: "transparent"
    exclusiveZone: 0
    aboveWindows: true
    WlrLayershell.namespace: "quickshell-controlcenter"
    WlrLayershell.layer: WlrLayer.Overlay

    WlrLayershell.keyboardFocus: (CcPanelState.visible && isTargetScreen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ── Click-away dismissal: clicking anywhere outside the card closes the panel ──
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: CcPanelState.dismiss()
    }

    // ── Keyboard shortcut: Escape always closes the panel regardless of child focus ──
    Shortcut {
        sequence: "Escape"
        enabled: panel.visible
        onActivated: CcPanelState.dismiss()
    }

    // ── Floating Center Card ──────────────────────────────────────────────
    Rectangle {
        id: card
        z: 1
        width: Theme.panelWidth
        height: content.implicitHeight + Theme.panelPadding * 2
        anchors.top: parent.top
        anchors.topMargin: Theme.panelMargin
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Theme.panelRadius
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.panelBorder

        // ── Content ───────────────────────────────────────────────────────────
        Column {
            id: content
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Theme.panelPadding
            anchors.leftMargin: Theme.panelPadding
            anchors.rightMargin: Theme.panelPadding
            spacing: Theme.sectionSpacing

            CcHeader {
                width: parent.width
                powerMenuOpen: CcPanelState.powerMenuOpen
                onLockRequested: CcSystem.runDetached(["hyprlock"])
                onPowerRequested: CcPanelState.powerMenuOpen = !CcPanelState.powerMenuOpen
                onSettingsRequested: CcSystem.runDetached(["xdg-open", Quickshell.shellDir])
                onEditRequested: CcSystem.runDetached(["sh", "-c", "for e in antigravity-ide code kate mousepad; do command -v \"$e\" >/dev/null && exec \"$e\" \"$1\"; done; exec xdg-open \"$1\"", "sh", Quickshell.shellDir + "/modules/controlcenter/Theme.qml"])
                onCloseRequested: CcPanelState.dismiss()
            }

            CcSliderRow {
                width: parent.width
            }

            CcTileGrid {
                width: parent.width
            }

            CcMediaSection {
                width: parent.width
            }

            CcNotificationsSection {
                width: parent.width
            }

            CcPowerMenu {
                width: parent.width
                visible: CcPanelState.powerMenuOpen
                onActionInvoked: CcPanelState.powerMenuOpen = false
            }
        }
    }
}
