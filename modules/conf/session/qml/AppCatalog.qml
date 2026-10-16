import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var policy: null
  property var hiddenIds: ({})
  property var desktopHiddenIds: ({})
  signal appsChanged()
  function entryName(entry) { return String(entry.name || entry.id || "") }
  function entrySubtext(entry) { return String(entry.genericName || "") }
  function sortedEntries(query) {
    var q = String(query || "").toLocaleLowerCase()
    var values = DesktopEntries.applications.values || []
    var rows = []
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (entry && !entry.noDisplay && !root.hiddenIds[entry.id] && !root.desktopHiddenIds[entry.id]
          && (!q || [entry.name, entry.genericName, entry.id].join(" ").toLocaleLowerCase().indexOf(q) >= 0)) rows.push({entry: entry})
    }
    return rows.sort(function(a, b) {
      return root.entryName(a.entry).localeCompare(root.entryName(b.entry))
    })
  }
  function iconSource(icon) { return Quickshell.iconPath(String(icon || "application-x-executable"), true) }
  function refreshIcons() { root.appsChanged() }
  function launch(desktopId, name) {
    if (!root.sortedEntries("").some(function(row) { return row.entry.id === desktopId })) return
    Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", desktopId + ".desktop"])
  }
  function remove(desktopId, name) {
    Quickshell.execDetached(["os", "remove", "launcher", "entry", desktopId, name])
  }
  function hiddenMap(text) {
    var result = ({})
    text.split(/\n/).forEach(function(line) {
      var id = line.trim().replace(/\.desktop$/, "")
      if (id && id.charAt(0) !== "#") result[id] = true
    })
    return result
  }
  FileView {
    path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/os/session/data/launcher.hides"
    watchChanges: true
    onLoaded: { root.hiddenIds = root.hiddenMap(text()); root.appsChanged() }
    onFileChanged: reload()
  }
  Process {
    id: hiddenScan
    command: root.policy ? [root.policy.runtime + "/shell/services/hidden-entries.sh", Quickshell.env("XDG_CURRENT_DESKTOP")] : []
    running: root.policy !== null
    stdout: StdioCollector { onStreamFinished: { root.desktopHiddenIds = root.hiddenMap(text); root.appsChanged() } }
  }
  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { if (hiddenScan.command.length) hiddenScan.running = true; root.appsChanged() }
  }
}
