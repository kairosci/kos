import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: app
    property var snapshot: null
    property string failure: ""
    property string page: "desktop"
    property string executable: Quickshell.shellPath("../../../../script/os-lua")
    readonly property var labels: snapshot ? snapshot.labels : ({})
    readonly property bool busy: readProcess.running || saveProcess.running
    function text(key) { return labels[key] || "" }
    function save(key, value) {
        if (busy) return
        failure = ""
        saveProcess.command = [executable, "settings-set", key, JSON.stringify(value)]
        saveProcess.running = true
    }
    Process {
        id: readProcess
        command: [app.executable, "settings-snapshot"]
        running: true
        stdout: StdioCollector { onStreamFinished: { if (text.trim()) app.snapshot = JSON.parse(text) } }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) app.failure = text } }
        onExited: (code, status) => { if (code !== 0) app.failure = app.text("failed") + "\n" + app.failure }
    }
    Process {
        id: saveProcess
        stdout: StdioCollector { onStreamFinished: { if (text.trim()) app.snapshot = JSON.parse(text) } }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) app.failure = text } }
        onExited: (code, status) => { if (code !== 0) { app.failure = app.text("failed") + "\n" + app.failure; readProcess.running = true } }
    }
    FileView {
        path: app.snapshot ? app.snapshot.palettePath : ""
        watchChanges: true
        onFileChanged: { if (!app.busy) readProcess.running = true }
    }
    ApplicationWindow {
        id: window
        visible: app.snapshot !== null || app.failure !== ""
        title: app.text("title")
        palette.window: app.snapshot ? app.snapshot.palette.window : systemPalette.window
        palette.windowText: app.snapshot ? app.snapshot.palette.windowText : systemPalette.windowText
        palette.base: app.snapshot ? app.snapshot.palette.base : systemPalette.base
        palette.alternateBase: app.snapshot ? app.snapshot.palette.alternateBase : systemPalette.alternateBase
        palette.text: app.snapshot ? app.snapshot.palette.text : systemPalette.text
        palette.button: app.snapshot ? app.snapshot.palette.button : systemPalette.button
        palette.buttonText: app.snapshot ? app.snapshot.palette.buttonText : systemPalette.buttonText
        palette.highlight: app.snapshot ? app.snapshot.palette.highlight : systemPalette.highlight
        palette.highlightedText: app.snapshot ? app.snapshot.palette.highlightedText : systemPalette.highlightedText
        palette.brightText: app.snapshot ? app.snapshot.palette.brightText : palette.highlightedText
        SystemPalette { id: systemPalette }
        width: app.snapshot ? app.snapshot.policy.window.width : minimumWidth
        height: app.snapshot ? app.snapshot.policy.window.height : minimumHeight
        minimumWidth: app.snapshot ? app.snapshot.policy.window.minimumWidth : 640
        minimumHeight: app.snapshot ? app.snapshot.policy.window.minimumHeight : 480
        onClosing: Qt.quit()
        footer: Label {
            padding: app.snapshot ? app.snapshot.policy.window.spacing : 0
            text: app.failure || (app.busy ? app.text("busy") : app.text("automatic"))
            wrapMode: Text.Wrap
            color: app.failure ? palette.brightText : palette.text
            background: Rectangle { color: app.failure ? palette.highlight : palette.alternateBase }
        }
        RowLayout {
            anchors.fill: parent
            spacing: 0
            Pane {
                Layout.preferredWidth: app.snapshot ? app.snapshot.policy.window.sidebar : 0
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    Repeater {
                        model: app.snapshot ? app.snapshot.policy.pages : []
                        Button {
                            required property string modelData
                            Layout.fillWidth: true
                            text: app.text(modelData)
                            icon.name: app.snapshot.policy.icons[modelData]
                            checked: app.page === modelData
                            checkable: true
                            onClicked: app.page = modelData
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Button { Layout.fillWidth: true; text: app.text("refresh"); enabled: !app.busy; onClicked: readProcess.running = true }
                }
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                Loader {
                    width: parent.width
                    active: app.snapshot !== null
                    source: app.page === "desktop" ? "DesktopPage.qml" : app.page === "network" ? "NetworkPage.qml" : app.page === "bluetooth" ? "BluetoothPage.qml" : "AudioPage.qml"
                    onLoaded: item.app = app
                }
            }
        }
    }
}
