import QtQuick
import QtQuick.Layouts
import "root:/modules/controlcenter"
import "root:/modules/common"
import "root:/modules/common/widgets"

/**
 * Reusable control center tile.
 *
 * Anatomy: rounded translucent rect (+1px border) holding a rounded-square
 * icon container on the left and two stacked text lines on the right.
 * `active` switches the fill to the accent gradient used for "on" states.
 */
Item {
    id: tile

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool interactive: true

    signal clicked()

    implicitHeight: Theme.tileHeight
    implicitWidth: 180

    scale: mouse.pressed && interactive ? Theme.tilePressedScale : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Theme.quickDuration
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Theme.tileRadius
        color: {
            if (tile.active)
                return "transparent"
            return mouse.containsMouse && tile.interactive ? Theme.tileBgHover : Theme.tileBg
        }
        border.width: 1
        border.color: tile.active ? Theme.activeBorder : Theme.tileBorder
        gradient: tile.active ? activeGradient : null

        Behavior on color {
            ColorAnimation { duration: Theme.colorDuration }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.colorDuration }
        }
    }

    Gradient {
        id: activeGradient
        GradientStop { position: 0.0; color: Theme.activeTop }
        GradientStop { position: 1.0; color: Theme.activeBottom }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.tilePaddingLeft
        anchors.rightMargin: Theme.tilePaddingRight
        spacing: Theme.tileInnerSpacing

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.tileIconBox
            implicitHeight: Theme.tileIconBox
            radius: Theme.tileIconRadius
            color: tile.active ? Theme.tileIconBgActive : Theme.tileIconBg

            Behavior on color {
                ColorAnimation { duration: Theme.colorDuration }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: tile.icon
                iconSize: Theme.tileIconSize
                font.family: Theme.iconFontFamily
                color: tile.active ? Theme.onAccent : Theme.accent

                Behavior on color {
                    ColorAnimation { duration: Theme.colorDuration }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.tileTextSpacing

            StyledText {
                Layout.fillWidth: true
                text: tile.title
                color: tile.active ? Theme.onAccent : Theme.textPrimary
                font.pixelSize: Appearance.font.pixelSize.textBase
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1

                Behavior on color {
                    ColorAnimation { duration: Theme.colorDuration }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: tile.subtitle
                color: tile.active ? Theme.textOnActiveDim : Theme.textDim
                font.pixelSize: Appearance.font.pixelSize.textSmall
                elide: Text.ElideRight
                maximumLineCount: 1

                Behavior on color {
                    ColorAnimation { duration: Theme.colorDuration }
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: tile.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: tile.interactive
        onClicked: tile.clicked()
    }
}
