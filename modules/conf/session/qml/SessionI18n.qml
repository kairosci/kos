pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root
  property var catalogue: ({})
  readonly property string language: catalogue.language || "en"
  readonly property var locale: Qt.locale(language)
  property FileView source: FileView {
    path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/os/session/data/translations.json"
    watchChanges: true
    onLoaded: root.catalogue = JSON.parse(text())
    onFileChanged: reload()
  }
  function text(value) {
    if (typeof value !== "string" || !value) return value
    var messages = catalogue.messages || ({})
    if (messages[value] !== undefined) return messages[value]
    var lower = value.toLocaleLowerCase()
    var lookup = catalogue.folded || ({})
    if (lookup[lower] !== undefined) {
      var translated = lookup[lower]
      return value === value.toLocaleUpperCase() ? translated.toLocaleUpperCase() : translated
    }
    var patterns = catalogue.patterns || []
    for (var i = 0; i < patterns.length; i++) {
      var match = value.match(new RegExp(patterns[i].match))
      if (match) return patterns[i].value.replace(/\$(\d+)/g, function(_, n) { return match[Number(n)] || "" })
    }
    return value
  }
  function formatDate(value, format) { return value.toLocaleDateString(locale, format) }
  function formatDateTime(value, format) { return value.toLocaleString(locale, format) }
}
