import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower

Pane {
    id: root
    property var app
    padding: app ? app.snapshot.policy.window.margin : 0
    ColumnLayout {
        width: parent.width
        spacing: root.app ? root.app.snapshot.policy.window.spacing : 0
        Label { text: root.app ? root.app.text("power") : ""; font.bold: true; font.pointSize: root.app ? root.app.snapshot.policy.window.titleSize : font.pointSize }
        Label {
            visible: UPower.displayDevice && UPower.displayDevice.isPresent
            text: root.app && UPower.displayDevice ? root.app.text("battery") + ": " + Math.round(UPower.displayDevice.percentage * 100) + "%" : ""
        }
        Repeater {
            model: root.app ? root.app.snapshot.sessionOptions : []
            RowLayout {
                id: row
                required property var modelData
                Layout.fillWidth: true
                enabled: root.app && !root.app.busy
                Label { Layout.fillWidth: true; text: root.app ? root.app.text(row.modelData.label) : ""; wrapMode: Text.Wrap }
                TextField {
                    text: row.modelData.value === null ? "" : String(row.modelData.value)
                    selectByMouse: true
                    onEditingFinished: { if (text.trim() !== "" && Number(text) !== row.modelData.value) root.app.saveSession(row.modelData.key, Number(text)) }
                }
            }
        }
    }
}
