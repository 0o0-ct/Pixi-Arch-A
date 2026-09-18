pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules/common"
import "root:/modules/common/functions/color_utils.js" as ColorUtils

/**
 * Control center theme.
 *
 * Geometry, typography and motion are hardcoded *here and only here*, so the
 * whole panel can be retuned from this one file.
 *
 * Colours are **not** hardcoded: they are derived from the wallust palette.
 * wallust renders `~/.config/wallust/templates/qml_color.json` to
 * `~/.config/quickshell/qml_color.json` on every wallpaper change; that file is
 * the same pipeline the shared design system consumes. `paletteFileView` below
 * watches it, so changing the wallpaper repaints the panel with no restart.
 *
 * Nothing else in the panel knows about wallust: every component keeps asking
 * for the roles below (`Theme.panelBg`, `Theme.tileBg`, ...).
 */
Singleton {
    id: theme

    // ══════════════════════════════════════════════════════════════════════
    //  TUNABLES — all hardcoded geometry / opacity of the panel
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Which outputs the panel is drawn on.
     *
     *   "all"    — the default: one panel instance per connected monitor, all
     *              toggled together as a single logical panel. Each instance is
     *              centred on its own output and reserves no space (`exclusiveZone: 0`).
     *   "<name>" — a specific output, e.g. "eDP-1" or "HDMI-A-1" (the names
     *              `hyprctl monitors` prints). The panel then exists only on
     *              that monitor.
     *
     * Matched against the connected outputs by `CcPanelState.panelScreens`,
     * which is the model of the `Variants` in `shell.qml`. A name that matches
     * nothing logs a warning and falls back to "all", so a typo cannot leave
     * the user without a panel.
     */
    readonly property string panelOutputs: "all"

    /**
     * Font used for MaterialSymbol glyphs.
     *
     * This is the one place the panel overrides a design-system token:
     * `Appearance.font.family.iconFont` points at "FiraConde Nerd Font",
     * which is not installed here, so the shared MaterialSymbol widget would
     * fall back to a text font and render ligature names literally
     * ("brightness_medium" instead of the glyph). "Material Symbols Rounded"
     * is what is actually installed and what MaterialSymbol is designed for.
     */
    readonly property string iconFontFamily: "Material Symbols Rounded"

    // Panel shell
    readonly property int panelWidth: 420
    readonly property int panelRadius: 18
    readonly property int panelMargin: 8
    readonly property int panelPadding: 14
    readonly property real panelAlpha: 0.92
    readonly property int sectionSpacing: 12

    // Header
    readonly property int avatarSize: 40
    readonly property int avatarRadius: 20
    readonly property string avatarImagePath: (Quickshell.env("HOME") ?? "") + "/.face"
    readonly property int iconButtonSize: 32
    readonly property int iconButtonIconSize: 18
    readonly property int headerSpacing: 10
    readonly property int headerButtonSpacing: 2

    // Sliders
    readonly property int sliderRowHeight: 22
    readonly property int sliderTrackHeight: 6
    readonly property int sliderIconSize: 16
    readonly property int sliderSpacing: 18
    readonly property int sliderGap: 8

    // Tiles
    readonly property int tileHeight: 56
    readonly property int tileRadius: 12
    readonly property int tileGap: 8
    readonly property int tileIconBox: 36
    readonly property int tileIconRadius: 10
    readonly property int tileIconSize: 20
    readonly property int tilePaddingLeft: 10
    readonly property int tilePaddingRight: 12
    readonly property int tileInnerSpacing: 10
    readonly property int tileTextSpacing: 2
    readonly property real tilePressedScale: 0.98

    // Notifications
    readonly property int notificationRadius: 12
    readonly property int notificationMaxHeight: 232
    readonly property int notificationItemHeight: 68
    readonly property int notificationSpacing: 6
    readonly property int notificationBodyLines: 2
    readonly property int notificationDismissSize: 26
    readonly property int notificationMaxAppWidth: 110

    // Motion — only opacity / scale / color are ever animated.
    readonly property int quickDuration: Math.round((Appearance.animation.elementMoveFast.duration ?? 200) * 0.75)
    readonly property int colorDuration: Appearance.animation.elementMoveFast.duration ?? 200

    // ══════════════════════════════════════════════════════════════════════
    //  WALLUST — colour tunables
    // ══════════════════════════════════════════════════════════════════════

    /** wallust's quickshell target (see ~/.config/wallust/wallust.toml). */
    readonly property string palettePath: {
        const configHome = Quickshell.env("XDG_CONFIG_HOME")
        const base = (configHome && configHome.length > 0)
            ? configHome
            : (Quickshell.env("HOME") ?? "") + "/.config"
        return base + "/quickshell/qml_color.json"
    }

    /** Print the palette in use to the journal on load / wallpaper change. */
    readonly property bool logPalette: true

    /**
     * How much of `accentPrimary` (wallust color7 — the one key of the qml
     * template that actually tracks the wallpaper) is mixed into each surface,
     * and the alpha each surface is painted at. These decide how strongly the
     * panel follows the wallpaper.
     */
    readonly property real tintPanel: 0.10
    readonly property real tintTile: 0.16
    readonly property real tintTileHover: 0.24
    readonly property real tintTileIcon: 0.30
    readonly property real alphaTile: 0.30
    readonly property real alphaTileIcon: 0.25

    /** Minimum WCAG contrast ratio every text role is held to. */
    readonly property real minContrast: 4.5

    // ══════════════════════════════════════════════════════════════════════
    //  PALETTE — wallust in, panel roles out
    // ══════════════════════════════════════════════════════════════════════

    /** Last successfully parsed wallust palette; `{}` until the file loads. */
    property var palette: ({})

    /** Set while a re-read is pending after an unparseable palette. */
    property bool paletteRetryPending: false

    /** Raw text of the palette currently applied, so a reload of the same
     *  contents is a no-op (`onTextChanged` and `onLoadedChanged` both fire on
     *  the first read). */
    property string appliedPaletteText: ""

    /** The tunables above, bundled for the derivation. */
    function tuning() {
        return {
            minContrast: minContrast,
            tintPanel: tintPanel,
            tintTile: tintTile,
            tintTileHover: tintTileHover,
            tintTileIcon: tintTileIcon,
            alphaTile: alphaTile,
            alphaTileIcon: alphaTileIcon,
            panelAlpha: panelAlpha,
        }
    }

    /**
     * Every panel colour, derived from the wallust palette in one pass.
     *
     * Pure: `(palette, tuning)` in, plain object out. Nothing here reads the
     * singleton, so the result cannot depend on evaluation order.
     */
    function deriveRoles(palette, t) {
        palette = palette ?? {}
        t = t ?? tuning()

        const bg = sanitizeColor(palette.windowBackground, "#161217")
        const primary = sanitizeColor(palette.primaryText, "#EAE0E7")
        const surfaceText = sanitizeColor(palette.surfaceText, "#EAE0E7")
        const secondary = sanitizeColor(palette.secondaryText, "#CFC3CD")
        const border = sanitizeColor(palette.borderPrimary, "#cba6f7")
        const accent = sanitizeColor(palette.accentPrimary, "#E5B6F2")
        const accentText = sanitizeColor(palette.accentPrimaryText, "#452152")

        // A surface is the wallpaper background nudged `tint` of the way toward
        // the accent, so the panel follows the wallpaper's hue without losing
        // its light/dark relationship with the text.
        const surface = tint => hexOf(mix(bg, accent, 1 - tint))

        // Opaque stand-ins for what the eye actually sees. The real surfaces do
        // keep their alpha and the wallpaper shows through ~8% of the panel,
        // which is far too little to change any of the ratios below.
        const panelFlat = surface(t.tintPanel)
        const tileFlat = overHex(surface(t.tintTile), 1 - t.alphaTile, panelFlat)
        const activeTopFlat = overHex(accent, 0.94, panelFlat)
        const activeBottomFlat = overHex(surface(0.85), 0.90, panelFlat)
        const iconActiveFlat = overHex(surface(0.88), 0.80, activeBottomFlat)
        // `onAccent` is drawn on the accent and on both ends of the active tile's
        // gradient, so it has to read on all of them, not just on the accent.
        const onAccentBackdrops = [accent, activeTopFlat, activeBottomFlat, iconActiveFlat]

        const textPrimary = readable(primary, tileFlat, [surfaceText, secondary], t)
        const textSecondary = readable(secondary, panelFlat, [surfaceText, primary], t)
        // wallust's template hardcodes accentPrimaryText to #FFFFFF, which is
        // unreadable on a light accent such as color7, so that token is only
        // kept when it really reads on the accent.
        const onAccent = readable(accentText, onAccentBackdrops, [primary, bg], t)
        const textDimAmount = dimTo(textSecondary, tileFlat, 0.30, t)
        const onActiveDimAmount = dimTo(onAccent, activeBottomFlat, 0.25, t)

        return {
            panelFlat: panelFlat,
            tileFlat: tileFlat,
            activeBottomFlat: activeBottomFlat,

            accent: rgba(accent, 1),
            onAccent: rgba(onAccent, 1),

            panelBg: rgba(surface(t.tintPanel), t.panelAlpha),
            panelBorder: rgba(border, 0.45),

            tileBg: rgba(surface(t.tintTile), 1 - t.alphaTile),
            tileBgHover: rgba(surface(t.tintTileHover), 1 - t.alphaTile),
            tileBorder: rgba(border, 0.28),
            tileIconBg: rgba(surface(t.tintTileIcon), 1 - t.alphaTileIcon),
            // The active tile's icon container has to stay on the accent side of
            // the contrast split: the glyph drawn on it is `onAccent`, while the
            // tile behind it is the accent gradient.
            tileIconBgActive: rgba(surface(0.88), 0.80),

            activeTop: rgba(accent, 0.94),
            activeBottom: rgba(surface(0.85), 0.90),
            activeBorder: rgba(accent, 0.65),

            textPrimary: rgba(textPrimary, 1),
            textSecondary: rgba(textSecondary, 1),
            textDim: rgba(textSecondary, 1 - textDimAmount),
            textOnActiveDim: rgba(onAccent, 1 - onActiveDimAmount),

            iconButtonHover: rgba(textPrimary, 0.10),
            trackDim: rgba(textPrimary, 0.16),
            trackFill: rgba(textPrimary, 0.88),
            divider: rgba(border, 0.22),

            contrast: {
                primaryOnPanel: contrastRatio(textPrimary, panelFlat),
                primaryOnTile: contrastRatio(textPrimary, tileFlat),
                dimOnTile: contrastRatio(overHex(textSecondary, 1 - textDimAmount, tileFlat), tileFlat),
                onAccentWorst: worstContrast(onAccent, onAccentBackdrops),
                onAccentOnAccent: contrastRatio(onAccent, accent),
                onAccentOnGradientTop: contrastRatio(onAccent, activeTopFlat),
                onAccentOnGradientBottom: contrastRatio(onAccent, activeBottomFlat),
                dimOnActiveGradient: contrastRatio(overHex(onAccent, 1 - onActiveDimAmount, activeBottomFlat), activeBottomFlat),
            },
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  ROLES — the only colour names the panel components know about
    // ══════════════════════════════════════════════════════════════════════
    //
    // Assigned by `applyRoles()` rather than initialised in place, because
    // `onAccent` cannot be initialised in place: this object also declares a
    // property called `accent`, and QML then reads `onAccent:` as a
    // signal-handler assignment for it. A plain value there is a load error, and
    // a binding is dropped *silently* — the property keeps its default forever,
    // which is what the previous version of this file was doing (`Theme.onAccent`
    // was always black).
    //
    // `applyRoles()` runs at startup and again on every palette load, so a
    // wallpaper change still repaints the panel.

    property var roles: ({})

    property color accent: "#E5B6F2"

    /** Assigned by `applyRoles()` — see the note above. */
    property color onAccent

    property color panelBg: "#161217"
    property color panelBorder: "#4C444D"

    property color tileBg: "#1F1A1F"
    property color tileBgHover: "#2D282E"
    property color tileBorder: "#4C444D"
    property color tileIconBg: "#2D282E"
    property color tileIconBgActive: "#161217"

    property color activeTop: "#E5B6F2"
    property color activeBottom: "#D5C0D7"
    property color activeBorder: "#cba6f7"

    property color textPrimary: "#EAE0E7"
    property color textSecondary: "#EAE0E7"
    property color textDim: "#CFC3CD"
    property color textOnActiveDim: "#452152"

    property color iconButtonHover: "#EAE0E7"
    property color trackDim: "#EAE0E7"
    property color trackFill: "#EAE0E7"
    property color divider: "#4C444D"

    /** Opaque stand-ins for the two text backdrops, for contrast reporting. */
    property string panelFlat: "#161217"
    property string tileFlat: "#1F1A1F"

    /** Derives every role from the current palette. */
    function applyRoles() {
        const r = deriveRoles(palette, tuning())
        theme.roles = r

        theme.accent = r.accent
        theme.onAccent = r.onAccent

        theme.panelBg = r.panelBg
        theme.panelBorder = r.panelBorder

        theme.tileBg = r.tileBg
        theme.tileBgHover = r.tileBgHover
        theme.tileBorder = r.tileBorder
        theme.tileIconBg = r.tileIconBg
        theme.tileIconBgActive = r.tileIconBgActive

        theme.activeTop = r.activeTop
        theme.activeBottom = r.activeBottom
        theme.activeBorder = r.activeBorder

        theme.textPrimary = r.textPrimary
        theme.textSecondary = r.textSecondary
        theme.textDim = r.textDim
        theme.textOnActiveDim = r.textOnActiveDim

        theme.iconButtonHover = r.iconButtonHover
        theme.trackDim = r.trackDim
        theme.trackFill = r.trackFill
        theme.divider = r.divider

        theme.panelFlat = r.panelFlat
        theme.tileFlat = r.tileFlat
    }

    Component.onCompleted: applyRoles()

    // ══════════════════════════════════════════════════════════════════════
    //  COLOUR HELPERS — pure functions of their arguments
    // ══════════════════════════════════════════════════════════════════════

    function hex2(value) {
        const n = Math.max(0, Math.min(255, Math.round(value * 255)))
        return (n < 16 ? "0" : "") + n.toString(16)
    }

    /** Any colour, alpha discarded, as `#rrggbb`. */
    function hexOf(color) {
        const c = Qt.color(color)
        return "#" + hex2(c.r) + hex2(c.g) + hex2(c.b)
    }

    /** An opaque `#rrggbb` colour at a given alpha. */
    function rgba(color, alpha) {
        const c = Qt.color(color)
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    /** `a` and `b` mixed, `weightA` being how much of `a` survives. */
    function mix(a, b, weightA) {
        const ca = Qt.color(a)
        const cb = Qt.color(b)
        return Qt.rgba(
            weightA * ca.r + (1 - weightA) * cb.r,
            weightA * ca.g + (1 - weightA) * cb.g,
            weightA * ca.b + (1 - weightA) * cb.b,
            1)
    }

    /** `color` — alpha and all — painted over an opaque `backdrop`. */
    function overBackdrop(color, backdrop) {
        const c = Qt.color(color)
        return hexOf(mix(Qt.rgba(c.r, c.g, c.b, 1), backdrop, c.a))
    }

    /** An opaque `#rrggbb` colour at `alpha`, painted over an opaque backdrop. */
    function overHex(color, alpha, backdrop) {
        return overBackdrop(rgba(color, alpha), backdrop)
    }

    /**
     * Accepts a wallust token and returns `#rrggbb`, or the fallback when it is
     * not a usable colour.
     *
     * wallust's qml template currently emits a double hash for two keys
     * (`"accentSecondary": "#{{color7}}"` and `"borderSecondary": "#{{color5}}"`,
     * where the substituted value already carries its own `#`). Qt rejects
     * `"##C4CEE5"`, so the extra hashes are stripped here and anything still
     * malformed falls back rather than poisoning a `color` property.
     */
    function sanitizeColor(value, fallback) {
        if (typeof value !== "string")
            return fallback
        let s = value.trim()
        while (s.startsWith("##"))
            s = s.slice(1)
        if (s.length === 6 && /^[0-9a-fA-F]{6}$/.test(s))
            s = "#" + s
        if (!/^#[0-9a-fA-F]{6}$/.test(s))
            return fallback
        return s.toLowerCase()
    }

    /** WCAG 2.x relative luminance of an opaque colour. */
    function luminance(color) {
        const c = Qt.color(color)
        const channel = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    /** WCAG contrast ratio between two opaque colours (1 … 21). */
    function contrastRatio(a, b) {
        const la = luminance(a)
        const lb = luminance(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }

    /**
     * The panel sits over an arbitrary wallpaper, so a text token is never
     * trusted to be readable on its own: `preferred` is kept when it clears the
     * minimum ratio, otherwise the first `fallbacks` entry that does, and pure
     * black or white only as a last resort.
     */
    /**
     * The lowest contrast `color` has against `against`, which is either one
     * opaque backdrop or a list of them (the colour then has to read on every
     * one, so the worst case is what counts).
     */
    function worstContrast(color, against) {
        if (!Array.isArray(against))
            return contrastRatio(color, against)
        let worst = Infinity
        for (let i = 0; i < against.length; i++)
            worst = Math.min(worst, contrastRatio(color, against[i]))
        return worst
    }

    /**
     * The panel sits over an arbitrary wallpaper, so a text token is never
     * trusted to be readable on its own: `preferred` is kept when it clears the
     * minimum ratio against every backdrop it is drawn on, otherwise the first
     * `fallbacks` entry that does, and pure black or white only as a last
     * resort.
     */
    function readable(preferred, against, fallbacks, t) {
        if (worstContrast(preferred, against) >= t.minContrast)
            return preferred
        for (let i = 0; i < fallbacks.length; i++) {
            if (fallbacks[i] && worstContrast(fallbacks[i], against) >= t.minContrast)
                return fallbacks[i]
        }
        return worstContrast("#ffffff", against) >= worstContrast("#000000", against) ? "#ffffff" : "#000000"
    }

    /**
     * The largest dimming of `color` that still clears the minimum ratio over
     * `backdrop`.
     *
     * Dimmed text is the tightest role in the panel and how much it can take
     * depends on the wallpaper, so the amount is solved for the palette that is
     * actually loaded rather than hardcoded.
     */
    function dimTo(color, against, maxAmount, t) {
        let amount = maxAmount
        while (amount > 0) {
            if (contrastRatio(overHex(color, 1 - amount, against), against) >= t.minContrast)
                return amount
            amount = Math.round((amount - 0.05) * 100) / 100
        }
        return 0
    }

    // ══════════════════════════════════════════════════════════════════════
    //  LOADING
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Applies a freshly read `qml_color.json`.
     *
     * Assigned wholesale (`palette = parsed`) rather than mutated, so the
     * derivation runs exactly once per load and the panel repaints — including
     * long after startup, when wallust rewrites the file for a new wallpaper.
     */
    function applyPalette(text) {
        if (text === theme.appliedPaletteText)
            return

        let parsed
        try {
            parsed = JSON.parse(text)
        } catch (error) {
            // wallust rewrites the target in place, and the watch can fire on the
            // truncation, before the new contents have landed. Re-read once
            // before treating the file as broken.
            if (!theme.paletteRetryPending) {
                theme.paletteRetryPending = true
                paletteRetry.start()
            } else {
                theme.paletteRetryPending = false
                console.warn("[controlcenter] wallust palette is not valid JSON, keeping the previous one: " + error)
            }
            return
        }
        theme.paletteRetryPending = false
        theme.appliedPaletteText = text
        if (!parsed || typeof parsed !== "object") {
            console.warn("[controlcenter] wallust palette is not an object, keeping the previous one")
            return
        }

        const ignored = []
        for (const key in parsed) {
            if (!sanitizeColor(parsed[key], null))
                ignored.push(key + "=" + JSON.stringify(parsed[key]))
        }
        theme.palette = parsed
        theme.applyRoles()

        if (!theme.logPalette)
            return
        const c = theme.roles.contrast
        console.log("[controlcenter] wallust palette from " + theme.palettePath
            + (ignored.length > 0 ? " (unusable, ignored: " + ignored.join(", ") + ")" : "")
            + " | panelBg " + theme.panelFlat
            + " tileBg " + theme.tileFlat
            + " textPrimary " + hexOf(theme.textPrimary)
            + " textDim " + overBackdrop(theme.textDim, theme.tileFlat)
            + " accent " + hexOf(theme.accent)
            + " onAccent " + hexOf(theme.onAccent)
            + " | contrast primary/panel " + c.primaryOnPanel.toFixed(2)
            + " primary/tile " + c.primaryOnTile.toFixed(2)
            + " dim/tile " + c.dimOnTile.toFixed(2)
            + " onAccent/accent " + c.onAccentOnAccent.toFixed(2)
            + " onAccent/worst " + c.onAccentWorst.toFixed(2)
            + " onAccent/gradient " + c.onAccentOnGradientBottom.toFixed(2)
            + " dimOnActive/gradient " + c.dimOnActiveGradient.toFixed(2))
    }

    /** One delayed re-read, for a palette caught mid-write. */
    Timer {
        id: paletteRetry
        interval: 100
        repeat: false
        onTriggered: paletteFileView.reload()
    }

    FileView {
        id: paletteFileView
        path: Qt.resolvedUrl(theme.palettePath)
        watchChanges: true

        // wallust rewrites the target in place on every wallpaper change; re-read
        // it here so the panel follows the wallpaper without a restart. The text
        // change is what carries the new contents: `loaded` does not toggle
        // again after the first read, so `onLoadedChanged` alone would only ever
        // see the startup palette.
        onFileChanged: reload()
        onTextChanged: theme.applyPalette(text())
        onLoadedChanged: {
            if (loaded)
                theme.applyPalette(text())
        }
    }
}
