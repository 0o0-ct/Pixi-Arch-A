import QtQuick
import "root:/modules/controlcenter"
import "root:/services"

/** Phase-1 tiles: network, bluetooth, audio out, battery, / and /home. */
Grid {
    id: grid

    columns: 2
    columnSpacing: Theme.tileGap
    rowSpacing: Theme.tileGap

    readonly property real cellWidth: (width - columnSpacing) / 2

    CcTile {
        width: grid.cellWidth
        icon: CcSystem.networkIcon
        title: CcSystem.networkTitle
        subtitle: CcSystem.networkSubtitle
        active: CcSystem.networkConnected
        onClicked: CcSystem.toggleWifi()
    }

    CcTile {
        width: grid.cellWidth
        icon: CcSystem.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
        title: CcSystem.bluetoothTitle
        subtitle: CcSystem.bluetoothSubtitle
        active: CcSystem.bluetoothEnabled
        onClicked: CcSystem.toggleBluetooth()
    }

    CcTile {
        width: grid.cellWidth
        icon: CcSystem.volumeIcon
        title: CcSystem.audioTitle
        subtitle: CcSystem.audioSubtitle
        active: !CcSystem.volumeMuted
        onClicked: CcSystem.toggleMute()
    }

    CcTile {
        width: grid.cellWidth
        icon: CcSystem.batteryIcon
        title: "Battery"
        subtitle: CcSystem.batterySubtitle
        active: CcSystem.batteryCharging
        interactive: false
    }

    CcTile {
        width: grid.cellWidth
        icon: CcSystem.rootDiskIcon
        title: "/"
        subtitle: CcSystem.rootDiskSubtitle
        active: false
        onClicked: CcSystem.refreshDisks()
    }

    CcTile {
        width: grid.cellWidth
        icon: CcSystem.homeDiskIcon
        title: "/home"
        subtitle: CcSystem.homeDiskSubtitle
        active: false
        onClicked: CcSystem.refreshDisks()
    }
}
