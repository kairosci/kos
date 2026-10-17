  property var sessionPolicy: null
  function sortMenuRows(rows) {
    rows.sort(function(a, b) {
      var aLabel = String(a.label || "").toLocaleLowerCase()
      var bLabel = String(b.label || "").toLocaleLowerCase()
      var comparison = aLabel.localeCompare(bLabel)
      if (comparison !== 0) return comparison
      return String(a.itemId || "").localeCompare(String(b.itemId || ""))
    })
  }
  FileView {
    path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/os/session/data/policy.json"
    watchChanges: true
    onLoaded: root.sessionPolicy = JSON.parse(text())
    onFileChanged: reload()
  }
  function status() {
    var entries = root.appLibrary ? root.appLibrary.sortedEntries("") : []
    root.mergeAppRows()
    var apps = root.itemOrder.filter(function(id) { return root.items[id] && root.items[id].kind === "app" })
    return JSON.stringify({
      policyLoaded: !!root.sessionPolicy,
      width: root.sessionPolicy ? root.sessionPolicy.menu.width : 0,
      renderedWidth: root.cardWidth,
      route: root.activeMenu,
      appLibraryReady: !!root.appLibrary,
      availableApps: entries.length,
      modelApps: apps.length,
      desktopApps: DesktopEntries.applications.values.length,
      menus: root.itemOrder.filter(function(id) { return root.items[id] && root.items[id].parent === "root" })
    })
  }
