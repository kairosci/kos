import QtQuick
import Quickshell
import "catalog" as Session

ShellRoot {
  Session.AppCatalog { id: catalog }
  Timer {
    interval: 100
    repeat: true
    running: true
    onTriggered: {
      var rows = catalog.sortedEntries("")
      if (rows.length !== 1 || rows[0].entry.id !== "visible") return
      if (catalog.entryName(rows[0].entry) !== "Visible fixture") return
      if (catalog.sortedEntries("missing").length !== 0) return
      catalog.launch("visible", "Visible fixture")
      console.log("session-appcatalog-valid")
      Qt.quit()
    }
  }
}
