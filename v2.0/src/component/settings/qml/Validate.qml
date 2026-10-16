import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    FileView {
        path: Quickshell.env("OS_SETTINGS_COMPONENTS")
        onLoaded: {
            for (const path of JSON.parse(text())) {
                const component = Qt.createComponent("file://" + path, Component.PreferSynchronous)
                if (component.status !== Component.Ready) {
                    console.error(component.errorString())
                    Qt.exit(1)
                    return
                }
            }
            console.log("settings-components-valid")
            Qt.quit()
        }
    }
}
