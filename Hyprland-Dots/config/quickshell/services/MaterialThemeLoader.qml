pragma Singleton
pragma ComponentBehavior: Bound

import "root:/modules/common"
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Automatically reloads generated material colors.
 * It is necessary to run reapplyTheme() on startup because Singletons are lazily loaded.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath

    function reapplyTheme() {
        themeFileView.reload()
    }

    // Only the legacy wallust keys that Appearance actually exposes.  The
    // generated file also contains m3 roles and metadata; assigning those as
    // dynamic m3 properties raises "non-existent property" errors in QML.
    readonly property var legacyKeys: [
        "windowBackground", "primaryText", "layerBackground1",
        "layerBackground2", "layerBackground3", "surfaceText",
        "secondaryText", "borderPrimary", "shadowColor",
        "accentPrimary", "accentSecondary", "selectionBackground",
        "accentPrimaryText", "selectionText", "borderSecondary"
    ]

    function applyColors(fileContent) {
        let json
        try {
            json = JSON.parse(fileContent)
        } catch (error) {
            console.warn("[MaterialThemeLoader] invalid palette JSON:", error)
            return
        }
        if (!json || typeof json !== "object")
            return

        for (const key of legacyKeys) {
            if (!json.hasOwnProperty(key))
                continue
            const camelCaseKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
            const m3Key = `m3${camelCaseKey}`
            Appearance.m3colors[m3Key] = json[key]
        }

        if (json.mode === "light" || json.mode === "dark") {
            Appearance.m3colors.darkmode = json.mode !== "light"
        } else if (typeof json.darkmode === "boolean") {
            Appearance.m3colors.darkmode = json.darkmode
        } else {
            Appearance.m3colors.darkmode =
                Appearance.m3colors.m3windowBackground.hslLightness < 0.5
        }
    }

    Timer {
        id: delayedFileRead
        interval: ConfigOptions?.hacks?.arbitraryRaceConditionDelay ?? 100
        repeat: false
        running: false
        onTriggered: {
            root.applyColors(themeFileView.text())
        }
    }

	FileView { 
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            this.reload()
            delayedFileRead.start()
        }
        onLoadedChanged: {
            const fileContent = themeFileView.text()
            root.applyColors(fileContent)
        }
    }
}
