pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "functions"

Singleton {
    id: root
    property QtObject m3colors
    property QtObject animation
    property QtObject animationCurves
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes

    // Generated once per wallpaper change by pixi_colors.py.  The overview
    // runs as its own Quickshell instance, so it cannot rely on the control
    // center's Theme singleton to read this file.
    readonly property string palettePath: {
        const configHome = Quickshell.env("XDG_CONFIG_HOME")
        const base = (configHome && configHome.length > 0)
            ? configHome
            : (Quickshell.env("HOME") ?? "") + "/.config"
        return base + "/quickshell/qml_color.json"
    }
    property string appliedPaletteText: ""

    function applyPalette(fileContent) {
        if (fileContent === root.appliedPaletteText)
            return

        let json
        try {
            json = JSON.parse(fileContent)
        } catch (error) {
            return
        }
        if (!json || typeof json !== "object")
            return

        root.appliedPaletteText = fileContent

        // New format: full M3 roles under "m3".  Only assign properties that
        // this Appearance exposes; the file contains roles used by other
        // shells too.
        const source = (json.m3 && typeof json.m3 === "object") ? json.m3 : null
        if (source) {
            for (const key in source) {
                const camel = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
                const m3Key = `m3${camel}`
                if (root.m3colors[m3Key] !== undefined)
                    root.m3colors[m3Key] = source[key]
            }
        } else {
            // Legacy wallust top-level keys.
            const legacy = {
                accentPrimary: "m3primary",
                accentSecondary: "m3secondary",
                selectionBackground: "m3secondaryContainer",
                windowBackground: "m3background",
                surfaceText: "m3onSurface",
                secondaryText: "m3onSurfaceVariant",
                borderPrimary: "m3outline",
                borderSecondary: "m3outlineVariant",
                shadowColor: "m3shadow"
            }
            for (const key in legacy) {
                if (json[key] !== undefined)
                    root.m3colors[legacy[key]] = json[key]
            }
        }

        if (json.mode === "light" || json.mode === "dark")
            root.m3colors.darkmode = json.mode !== "light"
        else if (typeof json.darkmode === "boolean")
            root.m3colors.darkmode = json.darkmode
    }

    FileView {
        id: paletteFile
        path: Qt.resolvedUrl(root.palettePath)
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            if (text().length > 0)
                root.applyPalette(text())
        }
        onLoadedChanged: {
            if (loaded)
                root.applyPalette(text())
        }
    }

    m3colors: QtObject {
        property bool darkmode: true
        property color m3primary: "#E5B6F2"
        property color m3onPrimary: "#452152"
        property color m3primaryContainer: "#5D386A"
        property color m3onPrimaryContainer: "#F9D8FF"
        property color m3secondary: "#D5C0D7"
        property color m3onSecondary: "#392C3D"
        property color m3secondaryContainer: "#534457"
        property color m3onSecondaryContainer: "#F2DCF3"
        property color m3background: "#161217"
        property color m3onBackground: "#EAE0E7"
        property color m3surface: "#161217"
        property color m3surfaceContainerLow: "#1F1A1F"
        property color m3surfaceContainer: "#231E23"
        property color m3surfaceContainerHigh: "#2D282E"
        property color m3surfaceContainerHighest: "#383339"
        property color m3onSurface: "#EAE0E7"
        property color m3surfaceVariant: "#4C444D"
        property color m3onSurfaceVariant: "#CFC3CD"
        property color m3inverseSurface: "#EAE0E7"
        property color m3inverseOnSurface: "#342F34"
        property color m3outline: "#988E97"
        property color m3outlineVariant: "#4C444D"
        property color m3shadow: "#000000"
    }

    colors: QtObject {
        property color colSubtext: m3colors.m3outline
        property color colLayer0: m3colors.m3background
        property color colOnLayer0: m3colors.m3onBackground
        property color colLayer0Border: ColorUtils.mix(root.m3colors.m3outlineVariant, colLayer0, 0.4)
        property color colLayer1: m3colors.m3surfaceContainerLow
        property color colOnLayer1: m3colors.m3onSurfaceVariant
        property color colOnLayer1Inactive: ColorUtils.mix(colOnLayer1, colLayer1, 0.45)
        property color colLayer1Hover: ColorUtils.mix(colLayer1, colOnLayer1, 0.92)
        property color colLayer1Active: ColorUtils.mix(colLayer1, colOnLayer1, 0.85)
        property color colLayer2: m3colors.m3surfaceContainer
        property color colOnLayer2: m3colors.m3onSurface
        property color colLayer2Hover: ColorUtils.mix(colLayer2, colOnLayer2, 0.90)
        property color colLayer2Active: ColorUtils.mix(colLayer2, colOnLayer2, 0.80)
        property color colPrimary: m3colors.m3primary
        property color colOnPrimary: m3colors.m3onPrimary
        property color colSecondary: m3colors.m3secondary
        property color colSecondaryContainer: m3colors.m3secondaryContainer
        property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer
        property color colTooltip: m3colors.m3inverseSurface
        property color colOnTooltip: m3colors.m3inverseOnSurface
        property color colShadow: ColorUtils.transparentize(m3colors.m3shadow, 0.7)
        property color colOutline: m3colors.m3outline
    }

    rounding: QtObject {
        property int unsharpen: 2
        property int verysmall: 8
        property int small: 12
        property int normal: 17
        property int large: 23
        property int full: 9999
        property int screenRounding: large
        property int windowRounding: 18
    }

    font: QtObject {
        property QtObject family: QtObject {
            property string main: "sans-serif"
            property string title: "sans-serif"
            property string expressive: "sans-serif"
        }
        property QtObject pixelSize: QtObject {
            property int smaller: 12
            property int small: 15
            property int normal: 16
            property int larger: 19
            property int huge: 22
        }
    }

    animationCurves: QtObject {
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1]
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveEffectsDuration: 200
    }

    animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: animationCurves.expressiveDefaultSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }

        property QtObject elementMoveEnter: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
                }
            }
        }
    }

    sizes: QtObject {
        property real elevationMargin: 10
    }
}
