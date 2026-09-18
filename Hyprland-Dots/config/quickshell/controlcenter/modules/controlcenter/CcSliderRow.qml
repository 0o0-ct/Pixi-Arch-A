import QtQuick
import QtQuick.Layouts
import "root:/modules/controlcenter"
import "root:/services"

/** Brightness on the left, output volume on the right. */
RowLayout {
    id: root

    spacing: Theme.sliderSpacing

    CcSlider {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        icon: CcSystem.brightnessIcon
        value: CcSystem.brightness
        onMoved: (value) => CcSystem.setBrightness(value)
    }

    CcSlider {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        icon: CcSystem.volumeIcon
        value: CcSystem.volume
        fillColor: CcSystem.volumeMuted ? Theme.trackDim : Theme.accent
        onMoved: (value) => CcSystem.setVolume(value)
    }
}
