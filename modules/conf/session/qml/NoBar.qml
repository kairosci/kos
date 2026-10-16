import QtQuick
import Quickshell.Io

Item {
  id: root
  property var shell: null
  property var manifest: null
  property var barConfig: ({})
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  readonly property bool barHidden: true
  readonly property int barSize: 0
  readonly property string position: "top"

  IpcHandler {
    enabled: root.manifest !== null
    target: root.manifest ? root.manifest.id : ""
    function status(): string { return JSON.stringify({barSurface: false, barSize: 0}) }
  }
}
