import Quickshell
import "../Components"

// Лаунчер приложений — радиальное колесо (RadialWheel) с поиском.
RadialWheel {
    id: root

    searchEnabled: true

    property string filterText: ""
    property var filteredApps: []

    model: filteredApps

    // приложения подгружаются асинхронно — обновляем список,
    // когда они появились
    readonly property int entryCount:
        DesktopEntries.applications.values.length

    onEntryCountChanged: updateFilter()

    onOpened: updateFilter()

    onSearchChanged: (text) => {
        filterText = text
        updateFilter()
    }

    onActivated: (item, index) => {
        Quickshell.execDetached({
            command: item.command,
            workingDirectory: item.workingDirectory
        })
        root.hide()
    }

    function updateFilter() {
        const appsSource = DesktopEntries.applications.values
            || DesktopEntries.applications
        const allApps = Array.from(appsSource)

        const q = filterText.trim().toLowerCase()
        const matches = q === ""
            ? allApps
            : allApps.filter(app =>
                app.name && app.name.toLowerCase().indexOf(q) !== -1)

        filteredApps = matches.map(app => ({
            label: app.name || "",
            icon: app.icon
                ? Quickshell.iconPath(app.icon, "application-x-executable")
                : "",
            command: app.command,
            workingDirectory: app.workingDirectory
        }))
    }
}
