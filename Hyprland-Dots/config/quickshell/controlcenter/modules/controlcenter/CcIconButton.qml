import QtQuick
import "root:/modules/controlcenter"
import "root:/modules/common"
import "root:/modules/common/widgets"

/**
 * Icon-only button with no background at rest, a subtle round hover
 * highlight and the design system's ripple on click.
 */
RippleButton {
    id: button

    property string iconName
    property color iconColor: Theme.textSecondary

    implicitWidth: Theme.iconButtonSize
    implicitHeight: Theme.iconButtonSize
    buttonRadius: Appearance.rounding.full

    colBackground: "transparent"
    colBackgroundHover: Theme.iconButtonHover
    colBackgroundToggled: Theme.accent
    colBackgroundToggledHover: Theme.accent
    colRipple: Theme.iconButtonHover
    colRippleToggled: Theme.iconButtonHover

    contentItem: MaterialSymbol {
        text: button.iconName
        iconSize: Theme.iconButtonIconSize
        font.family: Theme.iconFontFamily
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: button.toggled ? Theme.onAccent
            : (button.hovered ? Theme.textPrimary : button.iconColor)

        Behavior on color {
            ColorAnimation { duration: Theme.colorDuration }
        }
    }
}
