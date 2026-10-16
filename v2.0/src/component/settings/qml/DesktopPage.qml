import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: root
    property var app
    padding: app ? app.snapshot.policy.window.margin : 0
    ColumnLayout {
        width: parent.width
        spacing: root.app ? root.app.snapshot.policy.window.spacing : 0
        Label { text: root.app ? root.app.text("desktop") : ""; font.bold: true; font.pointSize: root.app ? root.app.snapshot.policy.window.titleSize : font.pointSize }
        TextField { id: search; Layout.fillWidth: true; placeholderText: root.app ? root.app.text("search") : "" }
        Repeater {
            model: root.app ? root.app.snapshot.options : []
            RowLayout {
                id: row
                required property var modelData
                Layout.fillWidth: true
                visible: !search.text || root.app.text(modelData.label).toLocaleLowerCase().includes(search.text.toLocaleLowerCase())
                enabled: !root.app.busy
                Label { Layout.fillWidth: true; text: root.app.text(row.modelData.label); wrapMode: Text.Wrap }
                Switch {
                    visible: row.modelData.kind === "boolean"
                    checked: row.modelData.value === true
                    onClicked: root.app.save(row.modelData.key, checked)
                }
                TextField {
                    visible: row.modelData.kind !== "boolean"
                    text: String(row.modelData.value)
                    selectByMouse: true
                    onEditingFinished: {
                        const value = row.modelData.kind === "number" ? Number(text) : text
                        if (value !== row.modelData.value) root.app.save(row.modelData.key, value)
                    }
                }
            }
        }
    }
}
