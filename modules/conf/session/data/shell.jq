def entry_id: if type == "string" then . else .id end;
.plugins = ((.plugins // []) | map(select(entry_id != "os.menu"))) + [{"id": "os.menu"}]
| .disabledPlugins = (((.disabledPlugins // []) + ["omarchy.menu"]) | unique)
| .bar.layout |= with_entries(.value |= map(select(entry_id != "os.menu" and entry_id != "omarchy.menu")))
