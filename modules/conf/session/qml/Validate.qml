import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
  FileView {
    path: Quickshell.env("OS_SESSION_COMPONENTS")
    onLoaded: {
      var files = JSON.parse(text())
      var failed = false
      for (var i = 0; i < files.length; i++) {
        var component = Qt.createComponent("file://" + files[i], Component.PreferSynchronous)
        if (component.status !== Component.Ready) {
          console.error("session-component-error", files[i], component.errorString())
          failed = true
        }
      }
      if (!failed) console.log("session-components-valid")
      Qt.quit()
    }
  }
}
