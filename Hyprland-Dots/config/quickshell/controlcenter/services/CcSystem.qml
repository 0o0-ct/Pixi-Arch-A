pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

/**
 * All real system integration for the control center lives here.
 *
 * Everything is either a QuickShell service singleton (Pipewire, Networking,
 * Bluetooth, UPower) or a short-lived `Process` running a CLI tool that is
 * actually present on the machine (`brightnessctl`, `cat`, `df`, `busctl`).
 * Nothing is hardcoded/faked: when a source is unavailable the property
 * reports an explicit "unknown" state instead of a plausible-looking value.
 */
Singleton {
    id: root

    // ══════════════════════════════════════════════════════════════════════
    //  Identity + uptime
    // ══════════════════════════════════════════════════════════════════════

    property string userName: Quickshell.env("USER") ?? ""
    property real uptimeSeconds: 0

    /** True only when $HOME/.face exists, so the avatar Image never warns. */
    property bool avatarAvailable: false

    readonly property string uptimeText: formatUptime(uptimeSeconds)

    function formatUptime(seconds) {
        const total = Math.max(0, Math.floor(seconds))
        const days = Math.floor(total / 86400)
        const hours = Math.floor((total % 86400) / 3600)
        const minutes = Math.floor((total % 3600) / 60)

        const parts = []
        if (days > 0)
            parts.push(days + (days === 1 ? " day" : " days"))
        if (days > 0 || hours > 0)
            parts.push(hours + (hours === 1 ? " hour" : " hours"))
        parts.push(minutes + (minutes === 1 ? " minute" : " minutes"))
        return "up " + parts.join(", ")
    }

    Process {
        id: whoamiProcess
        command: ["whoami"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = this.text.trim()
                if (name.length > 0)
                    root.userName = name
            }
        }
    }

    Process {
        id: avatarProcess
        command: ["sh", "-c", "test -f \"$HOME/.face\" && printf yes"]
        stdout: StdioCollector {
            onStreamFinished: root.avatarAvailable = this.text.trim() === "yes"
        }
    }

    // /proc/uptime is re-read instead of extrapolated from the wall clock, so
    // the value stays correct across suspend/resume.
    Process {
        id: uptimeProcess
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = this.text.trim().split(/\s+/)
                const up = parseFloat(fields[0])
                if (!isNaN(up))
                    root.uptimeSeconds = up
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: uptimeProcess.running = true
    }

    // ══════════════════════════════════════════════════════════════════════
    //  Brightness (brightnessctl)
    // ══════════════════════════════════════════════════════════════════════

    property real brightness: 0
    property string brightnessDevice: ""
    readonly property string brightnessIcon: brightness < 0.34 ? "brightness_low"
        : (brightness < 0.67 ? "brightness_medium" : "brightness_high")

    function setBrightness(value) {
        const clamped = Math.max(0.01, Math.min(1, value))
        root.brightness = clamped // optimistic, the poll confirms it
        brightnessSetter.command = ["brightnessctl", "set", Math.round(clamped * 100) + "%"]
        brightnessSetter.running = true
    }

    // `brightnessctl -m` -> "intel_backlight,backlight,6720,35%,19200"
    function parseBrightness(output) {
        const fields = output.trim().split(",")
        if (fields.length < 5)
            return
        const current = parseFloat(fields[2])
        const maximum = parseFloat(fields[4])
        if (!isNaN(current) && !isNaN(maximum) && maximum > 0) {
            root.brightnessDevice = fields[0]
            root.brightness = current / maximum
        }
    }

    Process {
        id: brightnessPoller
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: root.parseBrightness(this.text)
        }
    }

    Process {
        id: brightnessSetter
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: brightnessPoller.running = true
    }

    // ══════════════════════════════════════════════════════════════════════
    //  Audio output (PipeWire)
    // ══════════════════════════════════════════════════════════════════════

    readonly property var audioSink: Pipewire.defaultAudioSink

    /**
     * The Pipewire service only binds a node's audio interface (volume/muted)
     * when the node is tracked, so this keeps the default sink bound.
     */
    PwObjectTracker {
        objects: root.audioSink ? [root.audioSink] : []
    }

    readonly property real volume: audioSink?.audio?.volume ?? 0
    readonly property bool volumeMuted: audioSink?.audio?.muted ?? false
    readonly property string volumePercentText: Math.round(volume * 100) + "%"
    readonly property string volumeIcon: volumeMuted ? "volume_off"
        : (volume < 0.34 ? "volume_mute" : (volume < 0.67 ? "volume_down" : "volume_up"))
    readonly property string audioTitle: {
        if (!audioSink)
            return "No output device"
        const nickname = audioSink.nickname ?? ""
        const description = audioSink.description ?? ""
        return nickname.length > 0 ? nickname : (description.length > 0 ? description : audioSink.name)
    }
    readonly property string audioSubtitle: !audioSink ? "Unavailable"
        : (volumeMuted ? "Muted" : volumePercentText)

    function setVolume(value) {
        const audio = audioSink?.audio
        if (!audio)
            return
        audio.muted = false
        audio.volume = Math.max(0, Math.min(1, value))
    }

    function toggleMute() {
        const audio = audioSink?.audio
        if (audio)
            audio.muted = !audio.muted
    }

    // ══════════════════════════════════════════════════════════════════════
    //  Network (NetworkManager through Quickshell.Networking)
    // ══════════════════════════════════════════════════════════════════════

    readonly property var networkDevice: {
        const devices = Networking.devices.values ?? []
        if (devices.length === 0)
            return null
        for (const device of devices)
            if (device.connected)
                return device
        return devices[0]
    }

    readonly property bool networkConnected: networkDevice?.connected ?? false
    readonly property string networkTitle: {
        const device = networkDevice
        if (!device)
            return "No connection"
        if (device.type === DeviceType.Wired)
            return "Ethernet"
        if (device.type === DeviceType.Wifi)
            return "Wi-Fi"
        return "Network"
    }
    readonly property string networkSubtitle: {
        const device = networkDevice
        if (!device)
            return "Disconnected"
        if (device.type === DeviceType.Wifi && device.connected) {
            const networks = device.networks?.values ?? []
            for (const network of networks)
                if (network.connected && (network.name ?? "").length > 0)
                    return network.name
        }
        return device.connected ? "Connected" : "Disconnected"
    }
    readonly property string networkIcon: {
        const device = networkDevice
        if (!device)
            return "signal_wifi_off"
        if (device.type === DeviceType.Wired)
            return "settings_ethernet"
        return device.connected ? "wifi" : "wifi_off"
    }

    /** Wi-Fi radio is the thing the tile toggles. */
    readonly property bool wifiEnabled: Networking.wifiEnabled

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    // ══════════════════════════════════════════════════════════════════════
    //  Bluetooth (Integrated via bt_helper.py + bluetoothctl)
    // ══════════════════════════════════════════════════════════════════════

    property bool bluetoothEnabled: false
    property var bluetoothPairedDevices: []
    property var bluetoothAvailableDevices: []
    property bool bluetoothScanning: false
    property bool bluetoothDrawerOpen: false
    property string bluetoothDeviceName: ""

    readonly property string bluetoothTitle: bluetoothEnabled ? "Bluetooth" : "Disabled"
    readonly property string bluetoothSubtitle: {
        if (!bluetoothEnabled) return "No devices"
        if (bluetoothDeviceName.length > 0) return bluetoothDeviceName
        if (bluetoothPairedDevices.length > 0) return bluetoothPairedDevices.length + " paired"
        return "Enabled"
    }

    property string btHelperPath: Quickshell.shellDir + "/services/bt_helper.py"

    Process {
        id: btStatusProcess
        command: [root.btHelperPath, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.handleBtOutput(this.text)
        }
    }

    Process {
        id: btScanProcess
        command: [root.btHelperPath, "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothScanning = false
                root.handleBtOutput(this.text)
            }
        }
    }

    function handleBtOutput(jsonText) {
        try {
            const data = JSON.parse(jsonText.trim())
            root.bluetoothEnabled = data.powered ?? false
            root.bluetoothPairedDevices = data.paired ?? []
            root.bluetoothAvailableDevices = data.available ?? []
            let connectedName = ""
            for (let i = 0; i < root.bluetoothPairedDevices.length; i++) {
                if (root.bluetoothPairedDevices[i].connected) {
                    connectedName = root.bluetoothPairedDevices[i].name
                    break
                }
            }
            root.bluetoothDeviceName = connectedName
        } catch(e) {
            console.log("Error parsing bt output:", e)
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.refreshBluetooth()
    }

    Timer {
        id: btTimer
        interval: 1200
        repeat: false
        onTriggered: root.refreshBluetooth()
    }

    function refreshBluetooth() {
        if (!btStatusProcess.running && !btScanProcess.running) {
            btStatusProcess.running = true
        }
    }

    function toggleBluetooth() {
        root.runDetached([root.btHelperPath, "toggle"])
        btTimer.start()
    }

    function scanBluetooth() {
        if (!btScanProcess.running) {
            root.bluetoothScanning = true
            btScanProcess.running = true
        }
    }

    function connectBluetooth(mac) {
        root.runDetached([root.btHelperPath, "connect", mac])
        btTimer.start()
    }

    function disconnectBluetooth(mac) {
        root.runDetached([root.btHelperPath, "disconnect", mac])
        btTimer.start()
    }

    function pairBluetooth(mac) {
        root.runDetached([root.btHelperPath, "pair", mac])
        btTimer.start()
    }

    // ══════════════════════════════════════════════════════════════════════
    //  Battery (UPower)
    // ══════════════════════════════════════════════════════════════════════

    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool batteryPresent: batteryDevice?.isPresent ?? false

    /**
     * Quickshell 0.3.1 reports UPowerDevice.percentage as a 0..1 fraction;
     * the divide is only skipped if a 0..100 value ever shows up.
     */
    readonly property real batteryFraction: {
        const raw = batteryDevice?.percentage ?? 0
        return raw > 1 ? raw / 100 : raw
    }
    readonly property int batteryPercent: Math.round(batteryFraction * 100)
    readonly property string batteryStateText: {
        switch (batteryDevice?.state) {
        case UPowerDeviceState.Charging:
            return "Charging"
        case UPowerDeviceState.Discharging:
            return "Discharging"
        case UPowerDeviceState.FullyCharged:
            return "Plugged In"
        case UPowerDeviceState.PendingCharge:
            return "Plugged In"
        case UPowerDeviceState.PendingDischarge:
            return "Plugged In"
        default:
            return "Unknown"
        }
    }
    readonly property string batterySubtitle: batteryPresent
        ? batteryPercent + "% • " + batteryStateText
        : "No battery"
    readonly property bool batteryCharging: batteryPresent
        && (batteryDevice.state === UPowerDeviceState.Charging
            || batteryDevice.state === UPowerDeviceState.FullyCharged
            || batteryDevice.state === UPowerDeviceState.PendingCharge)
    readonly property string batteryIcon: {
        if (!batteryPresent)
            return "battery_unknown"
        if (batteryDevice.state === UPowerDeviceState.Charging
                || batteryDevice.state === UPowerDeviceState.FullyCharged
                || batteryDevice.state === UPowerDeviceState.PendingCharge)
            return "battery_charging_full"
        if (batteryPercent <= 20)
            return "battery_alert"
        return "battery_full"
    }

    // ══════════════════════════════════════════════════════════════════════
    //  Disks (`df`)
    // ══════════════════════════════════════════════════════════════════════

    property string rootDiskSubtitle: "Reading…"
    property string homeDiskSubtitle: "Reading…"
    readonly property string rootDiskIcon: "hard_disk"
    readonly property string homeDiskIcon: "home_storage"

    /**
     * Parses `df -hP <path>` (C locale, one line of data) into
     * "<used> / <total> (<percent>%)".
     */
    function parseDf(output) {
        const lines = output.trim().split("\n")
        if (lines.length < 2)
            return ""
        const fields = lines[1].trim().split(/\s+/)
        if (fields.length < 6)
            return ""
        return fields[2] + " / " + fields[1] + " (" + fields[4] + ")"
    }

    Process {
        id: rootDiskProcess
        command: ["df", "-hP", "/"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const text = root.parseDf(this.text)
                if (text.length > 0)
                    root.rootDiskSubtitle = text
            }
        }
    }

    Process {
        id: homeDiskProcess
        command: ["df", "-hP", "/home"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const text = root.parseDf(this.text)
                if (text.length > 0)
                    root.homeDiskSubtitle = text
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            rootDiskProcess.running = true
            homeDiskProcess.running = true
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  One-shot detached command runner (power menu, lock, "open settings")
    // ══════════════════════════════════════════════════════════════════════

    Process {
        id: runner
    }

    function runDetached(command) {
        runner.command = command
        runner.running = true
    }

    function refreshDisks() {
        rootDiskProcess.running = true
        homeDiskProcess.running = true
    }

    Component.onCompleted: {
        whoamiProcess.running = true
        avatarProcess.running = true
        uptimeProcess.running = true
        brightnessPoller.running = true
        rootDiskProcess.running = true
        homeDiskProcess.running = true
    }
}
