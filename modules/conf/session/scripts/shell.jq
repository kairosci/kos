def entry_id: if type == "string" then . else .id end;
($policy[0]) as $p
| ([.bar.layout[]?[]?] + (.plugins // [])) as $existing
| ([$p.menu.id] + [$p.panels[].id]) as $managed
| .plugins = ([ (.plugins // [])[] | select(entry_id as $id | ($managed | index($id)) == null and ($id | startswith("os.") | not)) ]
    + [{id: $p.menu.id}]
    + [$p.panels[] as $panel
       | ([$existing[] | select(entry_id == $panel.id or entry_id == ("omarchy." + $panel.source))] | last // {})
       | (if type == "object" then . else {} end) + {id: $panel.id}])
| .disabledPlugins = (((.disabledPlugins // []) + ["omarchy.menu"]) | unique)
| .bar = $defaults[0].bar
