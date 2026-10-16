import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire

Pane {
    id: root
    property var app
    padding: app ? app.snapshot.policy.window.margin : 0
    PwObjectTracker { objects: Pipewire.nodes.values }
    ColumnLayout {
        width: parent.width
        Label { text: root.app ? root.app.text("audio") : ""; font.bold: true; font.pointSize: root.app ? root.app.snapshot.policy.window.titleSize : font.pointSize }
        Label { visible: Pipewire.nodes.values.length === 0; text: root.app ? root.app.text("empty") : "" }
        Repeater {
            model: Pipewire.nodes
            ColumnLayout {
                id: nodeRow
                required property var modelData
                visible: modelData.audio !== null && !modelData.isStream
                Layout.fillWidth: true
                RadioButton {
                    text: nodeRow.modelData.description || nodeRow.modelData.name
                    checked: nodeRow.modelData === (nodeRow.modelData.isSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource)
                    onClicked: {
                        if (nodeRow.modelData.isSink) Pipewire.preferredDefaultAudioSink = nodeRow.modelData
                        else Pipewire.preferredDefaultAudioSource = nodeRow.modelData
                    }
                }
                Label { text: root.app ? root.app.text(nodeRow.modelData.isSink ? "output" : "input") : "" }
                Slider { Layout.fillWidth: true; from: 0; to: 1; value: nodeRow.modelData.audio ? nodeRow.modelData.audio.volume : 0; onMoved: { if (nodeRow.modelData.audio) nodeRow.modelData.audio.volume = value } }
                Switch { text: root.app ? root.app.text("mute") : ""; checked: nodeRow.modelData.audio ? nodeRow.modelData.audio.muted : false; onClicked: { if (nodeRow.modelData.audio) nodeRow.modelData.audio.muted = checked } }
            }
        }
    }
}
