import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root
  property var shell: null
  property var settings: null
  FileView {
    path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/os/session/data/policy.json"
    watchChanges: true
    onLoaded: root.settings = JSON.parse(text()).clockWidget
    onFileChanged: reload()
  }
  SystemClock { id: clock; precision: SystemClock.Minutes }
  Variants {
    model: root.settings && root.settings.enabled ? Quickshell.screens : []
    PanelWindow {
      required property var modelData
      screen: modelData
      WlrLayershell.namespace: "os-clock"
      anchors { top: root.settings && root.settings.anchor === "top-right"; right: true }
      margins { top: Style.gapsOut; right: Style.gapsOut }
      implicitWidth: label.implicitWidth + Style.space(24)
      implicitHeight: label.implicitHeight + Style.space(16)
      exclusiveZone: 0
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.layer: WlrLayer.Bottom
      color: "transparent"
      mask: Region {}
      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: Color.background
        border.color: Color.accent
        Text {
          id: label
          anchors.centerIn: parent
          text: Qt.formatDateTime(clock.date, root.settings ? root.settings.format : "")
          color: Color.foreground
          font.pixelSize: Style.space(32)
          font.family: Style.fontFamily
        }
      }
    }
  }
}
