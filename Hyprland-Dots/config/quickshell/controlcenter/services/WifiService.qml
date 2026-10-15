pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Networking

/**
 * Wi-Fi state shared by the control center drawer and the standalone
 * "netcenter" panel.
 *
 * Wraps Quickshell.Networking (NetworkManager): device lookup, the network
 * list ordered the way the UI shows it, and the connect flow — including the
 * password prompt state and the error feedback when a connection fails.
 */
Singleton {
    id: root

    // ══════════════════════════════════════════════════════════════════════
    //  DEVICES
    // ══════════════════════════════════════════════════════════════════════

    readonly property var wifiDevice: {
        const devices = Networking.devices?.values ?? []
        for (const device of devices)
            if (device.type === DeviceType.Wifi)
                return device
        return null
    }

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiConnected: root.wifiDevice?.connected ?? false

    // ══════════════════════════════════════════════════════════════════════
    //  NETWORK LIST
    // ══════════════════════════════════════════════════════════════════════

    /** Visible networks: connected first, then by signal strength, then A-Z. */
    readonly property var networks: {
        const list = (root.wifiDevice?.networks?.values ?? []).filter((network) => (network.name ?? "").length > 0)
        return list.slice().sort((a, b) => {
            if (!!a.connected !== !!b.connected)
                return a.connected ? -1 : 1
            const diff = (b.signalStrength ?? 0) - (a.signalStrength ?? 0)
            if (diff !== 0)
                return diff
            return (a.name ?? "").localeCompare(b.name ?? "")
        })
    }

    function signalPercent(network) {
        return Math.round((network?.signalStrength ?? 0) * 100)
    }

    /** True for networks that need no password (Open / OWE). */
    function isOpen(network) {
        return network?.security === WifiSecurityType.Open
            || network?.security === WifiSecurityType.Owe
    }

    /** Forces a rescan by restarting the device scanner. */
    function refreshScan() {
        const device = root.wifiDevice
        if (!device)
            return
        device.scannerEnabled = false
        device.scannerEnabled = true
    }

    // ══════════════════════════════════════════════════════════════════════
    //  CONNECT FLOW
    // ══════════════════════════════════════════════════════════════════════

    /** Network being connected to, or waiting for its password. */
    property var pendingNetwork: null
    property string pendingSsid: ""
    /** The password prompt is open (the drawer shows it inline). */
    property bool prompting: false
    /** A connection attempt is in flight. */
    property bool connecting: false
    /** Last error, shown by the prompt and by the drawer. */
    property string errorText: ""

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
        if (!Networking.wifiEnabled) {
            root.cancelPrompt()
            root.connecting = false
        }
    }

    function requestConnect(network) {
        if (!network)
            return
        root.errorText = ""
        if (network.connected) {
            network.disconnect()
            return
        }
        if (network.known || root.isOpen(network)) {
            root.beginConnect(network)
            network.connect()
        } else {
            root.pendingNetwork = network
            root.pendingSsid = network.name ?? ""
            root.prompting = true
        }
    }

    function submitPassword(password) {
        if (!root.pendingNetwork || (password ?? "").length === 0)
            return
        root.errorText = ""
        root.prompting = false
        root.beginConnect(root.pendingNetwork)
        root.pendingNetwork.connectWithPsk(password)
    }

    function cancelPrompt() {
        root.prompting = false
        root.errorText = ""
        root.pendingNetwork = null
    }

    function beginConnect(network) {
        root.pendingNetwork = network
        root.connecting = true
        timeoutTimer.restart()
    }

    /** Watchdog: a connection attempt that never reports back. */
    Timer {
        id: timeoutTimer
        interval: 30000
        onTriggered: {
            if (!root.connecting)
                return
            root.connecting = false
            root.errorText = "No se pudo conectar (tiempo agotado)"
            root.pendingNetwork = null
        }
    }

    Connections {
        target: root.pendingNetwork

        function onConnectedChanged() {
            if (!root.connecting || !root.pendingNetwork?.connected)
                return
            timeoutTimer.stop()
            root.connecting = false
            root.prompting = false
            root.errorText = ""
            root.pendingNetwork = null
        }

        function onConnectionFailed(reason) {
            if (!root.connecting)
                return
            timeoutTimer.stop()
            root.connecting = false
            root.errorText = "No se pudo conectar. Verificá la contraseña."
            const network = root.pendingNetwork
            if (network && !root.isOpen(network)) {
                root.pendingSsid = network.name ?? ""
                root.prompting = true
            }
        }
    }
}
