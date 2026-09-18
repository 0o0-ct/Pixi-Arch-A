pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

/**
 * Notification source for the control center.
 *
 * `server.trackedNotifications` is the QuickShell notification list; new
 * notifications are marked tracked so they stay in the list after their
 * popup expires.
 *
 * Only one process can own `org.freedesktop.Notifications` at a time, so the
 * owning process name is looked up once: when a different daemon
 * (swaync/dunst/mako) holds the bus this panel cannot receive notifications,
 * and the UI says so instead of silently showing an empty list.
 */
Singleton {
    id: root

    readonly property alias model: server.trackedNotifications

    /** Explicit row accessor so delegates never depend on role naming. */
    function at(index) {
        const values = server.trackedNotifications.values ?? []
        return (index >= 0 && index < values.length) ? values[index] : null
    }

    /** Process name owning org.freedesktop.Notifications, or "". */
    property string busOwner: ""

    readonly property bool selfOwnsBus: busOwner === "qs" || busOwner === "quickshell"
    readonly property bool blockedByOtherDaemon: busOwner.length > 0 && !selfOwnsBus

    readonly property string emptyMessage: {
        if (blockedByOtherDaemon)
            return "No notifications. " + busOwner
                + " currently owns org.freedesktop.Notifications; stop it to hand notifications to this panel."
        return "No notifications."
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: (notification) => {
            notification.tracked = true
        }
    }

    Process {
        id: busOwnerProcess
        command: ["sh", "-c",
            "busctl --user list 2>/dev/null | awk '$1==\"org.freedesktop.Notifications\"{print $3; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: root.busOwner = this.text.trim()
        }
    }

    Component.onCompleted: busOwnerProcess.running = true
}
